"""
需求分析 Agent

负责从自然语言需求中提取结构化信息，为测试设计提供基础。
"""

import json
import logging
from dataclasses import dataclass, asdict
from typing import Dict, Any, List, Optional
from app.integration.brconnector_client import BRConnectorClient, BRConnectorError

logger = logging.getLogger(__name__)


@dataclass
class AnalysisResult:
    """需求分析结果"""
    functional_points: List[str]  # 功能点
    business_rules: List[str]  # 业务规则
    input_specs: Dict[str, Any]  # 输入规格
    output_specs: Dict[str, Any]  # 输出规格
    exception_conditions: List[str]  # 异常条件
    constraints: List[str]  # 约束条件
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'AnalysisResult':
        """从字典创建"""
        return cls(**data)


class RequirementAnalysisAgent:
    """
    需求分析专家 Agent
    
    职责：
    - 从自然语言需求中提取功能点
    - 识别业务规则和约束
    - 确定输入/输出规格
    - 识别异常条件
    - 为测试设计提供结构化需求
    """
    
    # Prompt 模板
    SYSTEM_PROMPT = """你是一位资深的需求分析专家，擅长从自然语言需求中提取结构化信息。

你的任务是分析用户提供的需求描述，并提取以下信息：

1. **功能点 (Functional Points)**: 需要实现的功能或能力
2. **业务规则 (Business Rules)**: 控制行为的规则
3. **输入规格 (Input Specifications)**: 期望的输入（格式、范围、约束）
4. **输出规格 (Output Specifications)**: 应该产生的输出
5. **异常条件 (Exception Conditions)**: 应该处理的错误情况
6. **约束条件 (Constraints)**: 性能、安全或其他约束

请以 JSON 格式提供你的分析结果。"""
    
    ANALYSIS_PROMPT_TEMPLATE = """我的需求是：

{requirement}

---

参考以下历史 PRD 文档（如果与当前需求无相关性请不必理会）：

{historical_context}

---

请基于需求描述和历史 PRD 参考，提供结构化的分析结果，使用以下 JSON 格式：

```json
{{
  "functional_points": ["功能点1", "功能点2", ...],
  "business_rules": ["规则1", "规则2", ...],
  "input_specs": {{
    "参数名1": {{"type": "类型", "range": "范围", "required": true}},
    "参数名2": {{"type": "类型", "format": "格式"}}
  }},
  "output_specs": {{
    "返回值": {{"type": "类型", "description": "描述"}}
  }},
  "exception_conditions": ["异常1", "异常2", ...],
  "constraints": ["约束1", "约束2", ...]
}}
```

注意：
- 如果历史 PRD 中有相关的功能点、业务规则或约束，请参考并保持一致性
- 如果历史 PRD 与当前需求无关，请忽略它们，专注于当前需求
- 功能点应该清晰、可测试
- 业务规则应该明确、可验证
- 输入输出规格应该详细、具体
- 异常条件应该覆盖常见错误场景
- 约束条件应该包括性能、安全等非功能需求"""
    
    def __init__(self, brconnector_client: BRConnectorClient):
        """
        初始化需求分析 Agent
        
        Args:
            brconnector_client: BRConnector 客户端（用于调用 Claude API）
        """
        self.llm = brconnector_client
        self.logger = logging.getLogger(f"{__name__}.RequirementAnalysisAgent")
    
    async def analyze(
        self,
        requirement: str,
        context: Optional[Dict[str, Any]] = None
    ) -> AnalysisResult:
        """
        分析需求并提取结构化信息
        
        Args:
            requirement: 需求描述
            context: 可选的上下文信息（如历史 PRD）
            
        Returns:
            结构化的分析结果
            
        Raises:
            BRConnectorError: 如果 LLM 调用失败
            ValueError: 如果无法解析 LLM 响应
        """
        self.logger.info(f"开始分析需求，长度: {len(requirement)} 字符")
        
        # 准备历史上下文
        historical_context = "无历史 PRD 参考"
        if context and 'historical_prds' in context:
            prds = context['historical_prds']
            if prds:
                historical_context = ""
                for i, prd in enumerate(prds[:3], 1):  # 最多使用前 3 个
                    historical_context += f"\n### 历史 PRD {i}: {prd.get('title', 'N/A')}\n"
                    content = prd.get('content', '')
                    # 显示更多内容以提供更好的上下文
                    historical_context += f"{content[:500]}...\n"
                    historical_context += f"(相似度分数: {prd.get('score', 'N/A')})\n"
        
        # 构建提示词
        prompt = self.ANALYSIS_PROMPT_TEMPLATE.format(
            requirement=requirement,
            historical_context=historical_context
        )
        
        try:
            # 调用 LLM
            self.logger.debug("调用 Claude API 进行需求分析")
            response = await self.llm.chat_simple(
                prompt=prompt,
                system=self.SYSTEM_PROMPT,
                temperature=0.3,  # 较低温度以获得更一致的结果
                max_tokens=2000
            )
            
            self.logger.debug(f"收到 LLM 响应，长度: {len(response)} 字符")
            
            # 解析响应
            analysis_result = self._parse_analysis(response)
            
            self.logger.info(
                f"需求分析完成: {len(analysis_result.functional_points)} 个功能点, "
                f"{len(analysis_result.exception_conditions)} 个异常条件"
            )
            
            return analysis_result
        
        except BRConnectorError as e:
            self.logger.error(f"LLM 调用失败: {e}")
            raise
        except Exception as e:
            self.logger.error(f"需求分析失败: {e}")
            raise ValueError(f"需求分析失败: {e}") from e
    
    def _parse_analysis(self, raw_result: str) -> AnalysisResult:
        """
        解析 LLM 输出为结构化分析结果
        
        Args:
            raw_result: LLM 的原始响应
            
        Returns:
            解析后的分析结果
            
        Raises:
            ValueError: 如果无法解析响应
        """
        try:
            # 尝试提取 JSON（可能在 markdown 代码块中）
            json_str = raw_result.strip()
            
            # 如果响应包含 markdown 代码块，提取其中的 JSON
            if "```json" in json_str:
                start = json_str.find("```json") + 7
                end = json_str.find("```", start)
                json_str = json_str[start:end].strip()
            elif "```" in json_str:
                start = json_str.find("```") + 3
                end = json_str.find("```", start)
                json_str = json_str[start:end].strip()
            
            # 解析 JSON
            data = json.loads(json_str)
            
            # 验证必需字段
            required_fields = [
                'functional_points',
                'business_rules',
                'input_specs',
                'output_specs',
                'exception_conditions',
                'constraints'
            ]
            
            for field in required_fields:
                if field not in data:
                    self.logger.warning(f"缺少字段 '{field}'，使用默认值")
                    if field.endswith('_specs'):
                        data[field] = {}
                    else:
                        data[field] = []
            
            return AnalysisResult.from_dict(data)
        
        except json.JSONDecodeError as e:
            self.logger.error(f"JSON 解析失败: {e}")
            self.logger.debug(f"原始响应: {raw_result[:500]}...")
            raise ValueError(f"无法解析 LLM 响应为 JSON: {e}")
        except Exception as e:
            self.logger.error(f"解析分析结果失败: {e}")
            raise ValueError(f"解析分析结果失败: {e}")
