#!/usr/bin/env bash
# PreToolUse hook for Skill tool
# ce-compound 실행 시 Hindsight record 지시를 주입

if echo "$TOOL_INPUT" | grep -q "ce-compound"; then
  cat << 'EOF'
<compound-hindsight-hook>
compound Phase 2에서 docs/solutions/ 파일을 작성한 후, 서브에이전트 결과물을 활용하여 Hindsight retain API를 호출하라.
세션을 다시 분석하지 말고, 이미 수집된 서브에이전트 결과를 그대로 사용하라.
hindsight 스킬의 `record` 명령 절차를 따라 태그, document_id, context, metadata를 구성하라.
</compound-hindsight-hook>
EOF
fi

exit 0
