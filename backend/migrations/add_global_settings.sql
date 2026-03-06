-- ============================================
-- 添加全局配置表 (global_settings)
-- ============================================
CREATE TABLE IF NOT EXISTS global_settings (
    id VARCHAR(36) PRIMARY KEY,
    key VARCHAR(100) NOT NULL UNIQUE,
    value TEXT,
    type VARCHAR(50) NOT NULL DEFAULT 'string',
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_global_settings_key ON global_settings(key);

COMMENT ON TABLE global_settings IS '全局配置表（存储 Embedding API 等全局配置）';
COMMENT ON COLUMN global_settings.type IS '配置类型: string, number, boolean, json';

-- 添加触发器
CREATE TRIGGER update_global_settings_updated_at BEFORE UPDATE ON global_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 插入全局配置（Embedding API 配置）
-- 注意：请在部署后通过管理界面或环境变量设置真实的 API Key
INSERT INTO global_settings (id, key, value, type, description, created_at) VALUES
('gs-1', 'embedding_provider', 'volcano_ark', 'string', 'Embedding 服务提供商: mock, openai, volcano_ark', '2025-01-01 00:00:00'),
('gs-2', 'embedding_api_key', 'YOUR_API_KEY_HERE', 'string', 'Embedding API Key（请替换为真实的 API Key）', '2025-01-01 00:00:00'),
('gs-3', 'embedding_base_url', 'https://ark.cn-beijing.volces.com', 'string', 'Embedding API Base URL', '2025-01-01 00:00:00'),
('gs-4', 'embedding_model', 'ep-20260121110525-5mmss', 'string', 'Embedding 模型名称', '2025-01-01 00:00:00')
ON CONFLICT (key) DO NOTHING;
