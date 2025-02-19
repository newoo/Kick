#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 공통 경로 정의
BASE_PATH="../FeatureFlag"
FEATURE_DIR="$BASE_PATH/Sources/YAML/Feature"
OVERRIDE_DIR="$BASE_PATH/Sources/YAML/Override"
SWIFTGEN_CONFIG="$BASE_PATH/swiftgen.yml"

# 디렉토리 및 경로 초기화 함수
initialize_paths() {
    # 필요한 디렉토리 생성
    mkdir -p "$FEATURE_DIR" "$OVERRIDE_DIR"

    if [ ! -d "$FEATURE_DIR" ] || [ ! -d "$OVERRIDE_DIR" ]; then
        echo -e "${RED}디렉토리 생성에 실패했습니다.${NC}"
        exit 1
    fi
}

# SwiftGen 실행 함수
run_swiftgen() {
    echo -e "\n${BLUE}SwiftGen 실행 여부를 선택하세요.${NC}"
    read -p "$(echo -e "${GREEN}SwiftGen을 실행하시겠습니까? (y/n): ${NC}")" RUN_SWIFTGEN
    
    if [ "$RUN_SWIFTGEN" = "y" ]; then
        # SwiftGen config 실행
        echo -e "${BLUE}SwiftGen config 실행 중...${NC}"
        swiftgen config run -c "$SWIFTGEN_CONFIG"
        
        # 실행 결과 확인
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}SwiftGen 실행이 성공적으로 완료되었습니다.${NC}"
        else
            echo -e "${RED}SwiftGen 실행 중 오류가 발생했습니다.${NC}"
        fi
    else
        echo -e "${BLUE}SwiftGen 실행을 건너뛰었습니다.${NC}"
    fi
}

# 스크립트 시작 메시지
echo -e "${BLUE}Feature & Override YAML 생성기${NC}"
echo "------------------------------"

# 경로 초기화
initialize_paths

# 빠른 피처+오버라이드 YAML 생성 함수
create_quick_both_yamls() {
    echo -e "\n${BLUE}빠른 피처+오버라이드 YAML 생성${NC}"
    echo "------------------------------"
    
    read -p "$(echo -e "${GREEN}프로젝트 이름을 입력하세요 (기본값: ohouse): ${NC}")" PROJECT_NAME
    PROJECT_NAME=${PROJECT_NAME:-ohouse}
    
    read -p "$(echo -e "${GREEN}피처 이름을 입력하세요: ${NC}")" FEATURE_NAME
    DESCRIPTION="${FEATURE_NAME} feature"
    AUTHOR=$(whoami)
    SLACK_CHANNEL="eng-ios"

    # 피처 YAML 내용 생성
    YAML_CONTENT="version: feature/v1
metadata:
  namespace: ios
  projectName: $PROJECT_NAME
  featureName: $FEATURE_NAME
  description: $DESCRIPTION
  type: EXPERIMENTAL
  author: $AUTHOR
  slack: $SLACK_CHANNEL
parameters:"

    # 파라미터 정보 저장을 위한 배열
    declare -a PARAM_NAMES
    declare -a PARAM_TYPES
    declare -a PARAM_VALUES

    while true; do
        echo -e "\n${BLUE}파라미터 정보를 입력하세요${NC}"
        read -p "$(echo -e "${GREEN}파라미터 이름을 입력하세요: ${NC}")" PARAM_NAME
        read -p "$(echo -e "${GREEN}파라미터 타입을 입력하세요 (bool/string/int 등): ${NC}")" PARAM_TYPE
        read -p "$(echo -e "${GREEN}기본값을 입력하세요: ${NC}")" DEFAULT_VALUE
        
        PARAM_NAMES+=("$PARAM_NAME")
        PARAM_TYPES+=("$PARAM_TYPE")
        PARAM_VALUES+=("$DEFAULT_VALUE")
        
        YAML_CONTENT+="
- name: $PARAM_NAME
  type: $PARAM_TYPE
  value: $DEFAULT_VALUE"
        
        read -p "$(echo -e "${BLUE}파라미터를 더 추가하시겠습니까? (y/n): ${NC}")" ADD_MORE
        if [ "$ADD_MORE" != "y" ]; then
            break
        fi
    done

    FEATURE_YAML_PATH="$FEATURE_DIR/$(echo $FEATURE_NAME | tr '[:upper:]' '[:lower:]').yml"
    echo "$YAML_CONTENT" > "$FEATURE_YAML_PATH"
    echo -e "${GREEN}피처 YAML이 생성되었습니다: $FEATURE_YAML_PATH${NC}"

    # 오버라이드 YAML 생성
    while true; do
        echo -e "\n${BLUE}오버라이드 YAML 생성${NC}"
        DEFAULT_OVERRIDE_NAME="Override"
        read -p "$(echo -e "${GREEN}오버라이드 이름을 입력하세요 (기본값: ${FEATURE_NAME}Override): ${NC}")" OVERRIDE_NAME
        OVERRIDE_NAME=${OVERRIDE_NAME:-$DEFAULT_OVERRIDE_NAME}
        
        # App Scheme 선택
        echo -e "\n${BLUE}App Scheme을 선택하세요:${NC}"
        echo "1. domestic"
        echo "2. global"
        read -p "$(echo -e "${GREEN}선택 (1 또는 2): ${NC}")" SCHEME_CHOICE
        if [ "$SCHEME_CHOICE" = "1" ]; then
            APP_SCHEME="domestic"
        else
            APP_SCHEME="global"
        fi
        
        read -p "$(echo -e "${GREEN}XPC ID를 입력하세요 (숫자): ${NC}")" XPC_ID
        read -p "$(echo -e "${GREEN}Group을 입력하세요 (대문자 알파벳): ${NC}")" GROUP

        OVERRIDE_CONTENT="metadata:
  namespace: ios
  projectName: $PROJECT_NAME
  featureName: $FEATURE_NAME
  overrideName: $OVERRIDE_NAME
  description: ${FEATURE_NAME} override
rules:
  - operand: appScheme
    operator: EQ
    value: $APP_SCHEME
  - operand: xpc
    operator: EQ
    value:
      id: $XPC_ID
      group: $GROUP
parameters:"

        # 저장된 파라미터 정보를 사용하여 오버라이드 값 입력받기
        for i in "${!PARAM_NAMES[@]}"; do
            echo -e "\n${BLUE}파라미터: ${PARAM_NAMES[$i]} (타입: ${PARAM_TYPES[$i]})${NC}"
            read -p "$(echo -e "${GREEN}오버라이드할 값을 입력하세요: ${NC}")" OVERRIDE_VALUE
            
            OVERRIDE_CONTENT+="
- name: ${PARAM_NAMES[$i]}
  type: ${PARAM_TYPES[$i]}
  value: $OVERRIDE_VALUE"
        done

        OVERRIDE_YAML_PATH="$OVERRIDE_DIR/$(echo ${FEATURE_NAME}${OVERRIDE_NAME} | tr '[:upper:]' '[:lower:]').yml"
        echo "$OVERRIDE_CONTENT" > "$OVERRIDE_YAML_PATH"
        echo -e "${GREEN}오버라이드 YAML이 생성되었습니다: $OVERRIDE_YAML_PATH${NC}"

        read -p "$(echo -e "${BLUE}다른 오버라이드 YAML을 추가로 생성하시겠습니까? (y/n): ${NC}")" CREATE_MORE
        if [ "$CREATE_MORE" != "y" ]; then
            break
        fi
    done

    # SwiftGen 실행
    run_swiftgen
}

# 빠른 오버라이드 YAML 생성 함수
create_quick_override_yaml() {
    echo -e "\n${BLUE}빠른 오버라이드 YAML 생성${NC}"
    echo "------------------------------"
    
    # 피처 YAML 파일 읽기
    read -p "$(echo -e "${GREEN}피처 이름을 입력하세요: ${NC}")" FEATURE_NAME
    FEATURE_YAML_PATH="$FEATURE_DIR/$(echo $FEATURE_NAME | tr '[:upper:]' '[:lower:]').yml"
    
    if [ ! -f "$FEATURE_YAML_PATH" ]; then
        echo -e "${RED}해당 피처 YAML 파일을 찾을 수 없습니다: $FEATURE_YAML_PATH${NC}"
        exit 1
    fi

    # 기본 정보 읽기
    PROJECT_NAME=$(grep "projectName:" "$FEATURE_YAML_PATH" | cut -d: -f2 | tr -d ' ')
    PROJECT_NAME=${PROJECT_NAME:-ohouse}

    DEFAULT_OVERRIDE_NAME="Override"
    read -p "$(echo -e "${GREEN}오버라이드 이름을 입력하세요 (기본값: ${FEATURE_NAME}Override): ${NC}")" OVERRIDE_NAME
    OVERRIDE_NAME=${OVERRIDE_NAME:-$DEFAULT_OVERRIDE_NAME}
    DESCRIPTION="${FEATURE_NAME} override"
    
    # App Scheme 선택
    echo -e "\n${BLUE}App Scheme을 선택하세요:${NC}"
    echo "1. domestic"
    echo "2. global"
    read -p "$(echo -e "${GREEN}선택 (1 또는 2): ${NC}")" SCHEME_CHOICE
    if [ "$SCHEME_CHOICE" = "1" ]; then
        APP_SCHEME="domestic"
    else
        APP_SCHEME="global"
    fi
    
    read -p "$(echo -e "${GREEN}XPC ID를 입력하세요 (숫자): ${NC}")" XPC_ID
    read -p "$(echo -e "${GREEN}Group을 입력하세요 (대문자 알파벳): ${NC}")" GROUP

    # 오버라이드 YAML 생성 시작
    YAML_CONTENT="metadata:
  namespace: ios
  projectName: $PROJECT_NAME
  featureName: $FEATURE_NAME
  overrideName: $OVERRIDE_NAME
  description: $DESCRIPTION
rules:
  - operand: appScheme
    operator: EQ
    value: $APP_SCHEME
  - operand: xpc
    operator: EQ
    value:
      id: $XPC_ID
      group: $GROUP
parameters:"

    # 피처 YAML에서 파라미터 정보 추출 및 오버라이드 값 입력받기
    local IN_PARAMETERS=false
    while IFS= read -r line; do
        if [[ $line == "parameters:"* ]]; then
            IN_PARAMETERS=true
            continue
        fi
        
        if [ "$IN_PARAMETERS" = true ]; then
            if [[ $line =~ ^-[[:space:]]*name:[[:space:]]*(.+)$ ]]; then
                PARAM_NAME="${BASH_REMATCH[1]}"
                echo -e "\n${BLUE}파라미터: $PARAM_NAME${NC}"
            elif [[ $line =~ ^[[:space:]]*type:[[:space:]]*(.+)$ ]]; then
                PARAM_TYPE="${BASH_REMATCH[1]}"
                read -p "$(echo -e "${GREEN}오버라이드할 값을 입력하세요: ${NC}")" OVERRIDE_VALUE
                
                YAML_CONTENT+="
- name: $PARAM_NAME
  type: $PARAM_TYPE
  value: $OVERRIDE_VALUE"
            fi
        fi
    done < "$FEATURE_YAML_PATH"

    OVERRIDE_YAML_PATH="$OVERRIDE_DIR/$(echo ${FEATURE_NAME}${OVERRIDE_NAME} | tr '[:upper:]' '[:lower:]').yml"
    echo "$YAML_CONTENT" > "$OVERRIDE_YAML_PATH"
    echo -e "${GREEN}오버라이드 YAML이 생성되었습니다: $OVERRIDE_YAML_PATH${NC}"
    
    # SwiftGen 실행
    run_swiftgen
    
    return 0
}

# 메인 로직
echo -e "\n${BLUE}어떤 YAML을 생성하시겠습니까?${NC}"
echo "1. 피처 YAML"
echo "2. 오버라이드 YAML"
echo "3. 피처와 오버라이드 YAML 모두"
echo "4. 빠른 피처+오버라이드 YAML (심플버전)"
echo "5. 빠른 오버라이드 YAML (기존 피처 기반)"
read -p "$(echo -e "${GREEN}선택 (1, 2, 3, 4 또는 5): ${NC}")" YAML_TYPE

case $YAML_TYPE in
    1)
        create_feature_yaml
        run_swiftgen
        ;;
    2)
        while true; do
            create_override_yaml
            run_swiftgen
            read -p "$(echo -e "${BLUE}다른 오버라이드 YAML을 추가로 생성하시겠습니까? (y/n): ${NC}")" CREATE_MORE
            if [ "$CREATE_MORE" != "y" ]; then
                break
            fi
        done
        ;;
    3)
        create_feature_yaml
        while true; do
            create_override_yaml
            run_swiftgen
            read -p "$(echo -e "${BLUE}다른 오버라이드 YAML을 추가로 생성하시겠습니까? (y/n): ${NC}")" CREATE_MORE
            if [ "$CREATE_MORE" != "y" ]; then
                break
            fi
        done
        ;;
    4)
        create_quick_both_yamls
        ;;
    5)
        while true; do
            create_quick_override_yaml
            read -p "$(echo -e "${BLUE}다른 오버라이드 YAML을 추가로 생성하시겠습니까? (y/n): ${NC}")" CREATE_MORE
            if [ "$CREATE_MORE" != "y" ]; then
                break
            fi
        done
        ;;
    *)
        echo -e "${RED}잘못된 선택입니다. 1, 2, 3, 4, 5 중에서 선택해주세요.${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}YAML 생성이 완료되었습니다.${NC}"

