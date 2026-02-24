"""
测试设计 Agent

负责基于需求分析结果设计全面的测试用例。
"""

import json
import logging
from dataclasses import dataclass, asdict
from typing import List, Dict, Any, Optional
from app.integration.brconnector_client import BRConnectorClient, BRConnectorError
from app.agent.requirement_analysis_agent import AnalysisResult

logger = logging.getLogger(__name__)


@dataclass
class TestCaseDesign:
    """测试用例设计"""
    title: str  # 标题
    preconditions: str  # 前置条件
    steps: List[str]  # 测试步骤
    expected_result: str  # 预期结果
    priority: str  # 优先级: 'high' | 'medium' | 'low'
    type: str  # 类型: 'functional' | 'boundary' | 'exception' | 'security' | 'performance'
    rationale: str  # 设计理由
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'TestCaseDesign':
        """从字典创建"""
        return cls(**data)


class TestDesignAgent:
    """
    测试设计专家 Agent
    
    职责：
    - 生成主流程测试场景
    - 结合我现有测试用例内容格式以及表达生成
    - 设计异常流程测试用例
    - 识别边界值测试点
    - 创建组合场景
    - 设计安全和性能测试点
    """
    
    # Prompt 模板
    SYSTEM_PROMPT = """你是一位资深的测试设计专家，专注于全面的测试覆盖。

你的任务是基于需求分析结果设计测试用例，覆盖以下方面：

1. **主流程 (Main Flow)**: 正常路径场景
2. **异常流程 (Exception Flow)**: 错误处理和边缘情况
3. **边界值 (Boundary Values)**: 最小值、最大值和边界条件
4. **组合场景 (Combination Scenarios)**: 多个条件交互
5. **安全测试 (Security Tests)**: 认证、授权、输入验证
6. **性能测试 (Performance Tests)**: 负载、压力、可扩展性考虑

对于每个测试用例，请提供：
- **title**: 清晰、描述性的名称
- **preconditions**: 测试前需要的设置
- **steps**: 编号的、可操作的步骤
- **expected_result**: 清晰的成功标准
- **priority**: High/Medium/Low
- **type**: Functional/Boundary/Exception/Security/Performance
- **rationale**: 为什么这个测试用例很重要

请以 JSON 数组格式输出测试用例。"""
    
    DESIGN_PROMPT_TEMPLATE = """我的需求分析结果如下：

{analysis}

---

参考以下历史测试用例（如果与当前需求无相关性请不必理会）：

{historical_cases}

---

请基于需求分析结果和历史测试用例参考，设计全面的测试用例，使用以下 JSON 数组格式：

```json
[
  {{
    "title": "测试用例标题",
    "preconditions": "前置条件描述",
    "steps": ["步骤1", "步骤2", "步骤3"],
    "expected_result": "预期结果描述",
    "priority": "high",
    "type": "functional",
    "rationale": "设计理由"
  }},
  ...
]
```

注意：
- 如果历史测试用例中有相似的测试场景，请参考其测试步骤的表达方式和结构
- 如果历史测试用例与当前需求无关，请忽略它们，专注于当前需求
- 确保覆盖需求分析中的所有功能点
- 包含异常和边界值测试
- 步骤应该清晰、可操作，参考历史用例的表达风格
- 预期结果应该具体、可衡量
- 优先级应该合理分配（high/medium/low）
- 类型应该正确分类（functional/boundary/exception/security/performance）"""
    
    def __init__(self, brconnector_client: BRConnectorClient):
        """
        初始化测试设计 Agent
        
        Args:
            brconnector_client: BRConnector 客户端（用于调用 Claude API）
        """
        self.llm = brconnector_client
        self.logger = logging.getLogger(f"{__name__}.TestDesignAgent")
    
    async def design_tests(
        self,
        analysis: AnalysisResult,
        historical_cases: Optional[List[Dict[str, Any]]] = None
    ) -> List[TestCaseDesign]:
        """
        基于需求分析设计测试用例
        
        Args:
            analysis: 需求分析结果
            historical_cases: 可选的历史测试用例
            
        Returns:
            测试用例设计列表
            
        Raises:
            BRConnectorError: 如果 LLM 调用失败
            ValueError: 如果无法解析 LLM 响应
        """
        self.logger.info(
            f"开始设计测试用例，功能点数: {len(analysis.functional_points)}"
        )
        
        # 准备历史测试用例上下文
        historical_context = "无历史测试用例参考"
        if historical_cases:
            historical_context = ""
            for i, case in enumerate(historical_cases[:5], 1):  # 最多使用前 5 个
                historical_context += f"\n### 历史测试用例 {i}: {case.get('title', 'N/A')}\n"
                historical_context += f"**前置条件**: {case.get('preconditions', 'N/A')}\n"
                
                # 显示完整的测试步骤
                if 'steps' in case:
                    steps = case['steps'] if isinstance(case['steps'], list) else []
                    historical_context += f"**测试步骤**:\n"
                    for j, step in enumerate(steps[:10], 1):  # 最多显示 10 个步骤
                        historical_context += f"  {j}. {step}\n"
                
                historical_context += f"**预期结果**: {case.get('expected_result', 'N/A')}\n"
                historical_context += f"**优先级**: {case.get('priority', 'N/A')}\n"
                historical_context += f"(相似度分数: {case.get('score', 'N/A')})\n"
        
        # 构建提示词
        prompt = self.DESIGN_PROMPT_TEMPLATE.format(
            analysis=json.dumps(analysis.to_dict(), ensure_ascii=False, indent=2),
            historical_cases=historical_context
        )
        
        try:
            # 调用 LLM
            self.logger.debug("调用 Claude API 进行测试设计")
            response = await self.llm.chat_simple(
                prompt=prompt,
                system=self.SYSTEM_PROMPT,
                temperature=0.5,  # 中等温度以平衡创造性和一致性
                max_tokens=4000
            )
            
            self.logger.debug(f"收到 LLM 响应，长度: {len(response)} 字符")
            
            # 解析响应
            test_designs = self._parse_test_designs(response)
            
            self.logger.info(f"测试设计完成: 生成 {len(test_designs)} 个测试用例")
            
            return test_designs
        
        except BRConnectorError as e:
            self.logger.error(f"LLM 调用失败: {e}")
            raise
        except Exception as e:
            self.logger.error(f"测试设计失败: {e}")
            raise ValueError(f"测试设计失败: {e}") from e
    
    def _parse_test_designs(self, raw_result: str) -> List[TestCaseDesign]:
        """
        解析 LLM 输出为测试用例设计列表
        
        Args:
            raw_result: LLM 的原始响应
            
        Returns:
            解析后的测试用例设计列表
            
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
                if end == -1:
                    # 没有找到结束标记，取到字符串末尾
                    json_str = json_str[start:].strip()
                else:
                    json_str = json_str[start:end].strip()
            elif "```" in json_str:
                start = json_str.find("```") + 3
                end = json_str.find("```", start)
                if end == -1:
                    json_str = json_str[start:].strip()
                else:
                    json_str = json_str[start:end].strip()
            
            # 尝试修复常见的 JSON 问题
            # 1. 移除可能的 BOM 和控制字符
            json_str = json_str.replace('\ufeff', '').replace('\x00', '')
            
            # 2. 如果 JSON 不完整（缺少结束括号），尝试修复
            if json_str.count('[') > json_str.count(']'):
                json_str += ']' * (json_str.count('[') - json_str.count(']'))
            if json_str.count('{') > json_str.count('}'):
                json_str += '}' * (json_str.count('{') - json_str.count('}'))
            
            # 解析 JSON
            try:
                data = json.loads(json_str)
            except json.JSONDecodeError as e:
                self.logger.error(f"JSON 解析失败: {e}")
                self.logger.debug(f"原始响应: {raw_result[:500]}...")
                self.logger.debug(f"提取的 JSON: {json_str[:500]}...")
                raise ValueError(f"无法解析 LLM 响应为 JSON: {e}")
            
            # 确保是列表
            if not isinstance(data, list):
                raise ValueError("响应应该是测试用例数组")
            
            # 转换为 TestCaseDesign 对象
            test_designs = []
            for i, item in enumerate(data):
                try:
                    # 验证必需字段
                    required_fields = [
                        'title', 'preconditions', 'steps',
                        'expected_result', 'priority', 'type'
                    ]
                    
                    for field in required_fields:
                        if field not in item:
                            self.logger.warning(
                                f"测试用例 {i} 缺少字段 '{field}'，跳过"
                            )
                            continue
                    
                    # 添加默认 rationale（如果缺失）
                    if 'rationale' not in item:
                        item['rationale'] = ""
                    
                    # 标准化优先级和类型
                    item['priority'] = item['priority'].lower()
                    item['type'] = item['type'].lower()
                    
                    # 确保 steps 是列表
                    if not isinstance(item['steps'], list):
                        item['steps'] = [str(item['steps'])]
                    
                    test_designs.append(TestCaseDesign.from_dict(item))
                
                except Exception as e:
                    self.logger.warning(f"跳过无效的测试用例 {i}: {e}")
                    continue
            
            if not test_designs:
                raise ValueError("没有有效的测试用例")
            
            return test_designs
        
        except json.JSONDecodeError as e:
            self.logger.error(f"JSON 解析失败: {e}")
            self.logger.debug(f"原始响应: {raw_result[:500]}...")
            raise ValueError(f"无法解析 LLM 响应为 JSON: {e}")
        except Exception as e:
            self.logger.error(f"解析测试设计失败: {e}")
            raise ValueError(f"解析测试设计失败: {e}")
