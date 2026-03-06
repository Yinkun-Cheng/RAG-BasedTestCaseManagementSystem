-- RAG 测试用例管理系统 - 完整数据库结构
-- PostgreSQL 数据库
-- 创建时间: 2025-01-20

-- ============================================
-- 1. 项目表 (projects)
-- ============================================
CREATE TABLE IF NOT EXISTS projects (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_projects_deleted_at ON projects(deleted_at);
CREATE INDEX idx_projects_created_at ON projects(created_at);

COMMENT ON TABLE projects IS '项目表';
COMMENT ON COLUMN projects.id IS '项目ID';
COMMENT ON COLUMN projects.name IS '项目名称';
COMMENT ON COLUMN projects.description IS '项目描述';

-- ============================================
-- 2. App 版本表 (app_versions)
-- ============================================
CREATE TABLE IF NOT EXISTS app_versions (
    id VARCHAR(36) PRIMARY KEY,
    project_id VARCHAR(36) NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    version VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_app_versions_project_id ON app_versions(project_id);
CREATE INDEX idx_app_versions_deleted_at ON app_versions(deleted_at);
CREATE UNIQUE INDEX idx_app_versions_project_version ON app_versions(project_id, version) WHERE deleted_at IS NULL;

COMMENT ON TABLE app_versions IS 'App版本表';
COMMENT ON COLUMN app_versions.version IS '版本号，如 v1.0.0';

-- ============================================
-- 3. 功能模块表 (modules)
-- ============================================
CREATE TABLE IF NOT EXISTS modules (
    id VARCHAR(36) PRIMARY KEY,
    project_id VARCHAR(36) NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id VARCHAR(36) REFERENCES modules(id) ON DELETE CASCADE,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_modules_project_id ON modules(project_id);
CREATE INDEX idx_modules_parent_id ON modules(parent_id);
CREATE INDEX idx_modules_deleted_at ON modules(deleted_at);
CREATE INDEX idx_modules_sort_order ON modules(sort_order);

COMMENT ON TABLE modules IS '功能模块表（树形结构）';
COMMENT ON COLUMN modules.parent_id IS '父模块ID，NULL表示根模块';
COMMENT ON COLUMN modules.sort_order IS '排序字段';

-- ============================================
-- 4. 标签表 (tags)
-- ============================================
CREATE TABLE IF NOT EXISTS tags (
    id VARCHAR(36) PRIMARY KEY,
    project_id VARCHAR(36) NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    color VARCHAR(20),
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_tags_project_id ON tags(project_id);
CREATE INDEX idx_tags_name ON tags(name);
CREATE INDEX idx_tags_deleted_at ON tags(deleted_at);
CREATE UNIQUE INDEX idx_tags_project_name ON tags(project_id, name) WHERE deleted_at IS NULL;

COMMENT ON TABLE tags IS '标签表';
COMMENT ON COLUMN tags.color IS '标签颜色，如 red, blue, green';

-- ============================================
-- 5. PRD 文档表 (prd_documents)
-- ============================================
CREATE TABLE IF NOT EXISTS prd_documents (
    id VARCHAR(36) PRIMARY KEY,
    project_id VARCHAR(36) NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    app_version_id VARCHAR(36) NOT NULL REFERENCES app_versions(id) ON DELETE RESTRICT,
    code VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    module_id VARCHAR(36) REFERENCES modules(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    version INT NOT NULL DEFAULT 1,
    author VARCHAR(100),
    synced_to_vector BOOLEAN DEFAULT FALSE,
    sync_status VARCHAR(20),
    last_synced_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_prd_documents_project_id ON prd_documents(project_id);
CREATE INDEX idx_prd_documents_app_version_id ON prd_documents(app_version_id);
CREATE INDEX idx_prd_documents_module_id ON prd_documents(module_id);
CREATE INDEX idx_prd_documents_status ON prd_documents(status);
CREATE INDEX idx_prd_documents_version ON prd_documents(version);
CREATE INDEX idx_prd_documents_deleted_at ON prd_documents(deleted_at);
CREATE INDEX idx_prd_documents_code ON prd_documents(code);
CREATE INDEX idx_prd_documents_sync_status ON prd_documents(sync_status);
CREATE UNIQUE INDEX idx_prd_documents_project_code ON prd_documents(project_id, code) WHERE deleted_at IS NULL;

COMMENT ON TABLE prd_documents IS 'PRD文档表';
COMMENT ON COLUMN prd_documents.code IS 'PRD编号';
COMMENT ON COLUMN prd_documents.status IS '状态: draft-草稿, published-已发布, archived-已归档';
COMMENT ON COLUMN prd_documents.version IS '版本号（整数递增）';
COMMENT ON COLUMN prd_documents.sync_status IS '同步状态: syncing-同步中, synced-已同步, failed-失败';
COMMENT ON COLUMN prd_documents.synced_to_vector IS '是否已同步到向量数据库';

-- ============================================
-- 6. PRD 版本历史表 (prd_versions)
-- ============================================
CREATE TABLE IF NOT EXISTS prd_versions (
    id VARCHAR(36) PRIMARY KEY,
    prd_id VARCHAR(36) NOT NULL REFERENCES prd_documents(id) ON DELETE CASCADE,
    version INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    change_log TEXT,
    created_by VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_prd_versions_prd_id ON prd_versions(prd_id);
CREATE INDEX idx_prd_versions_version ON prd_versions(version);
CREATE UNIQUE INDEX idx_prd_versions_prd_version ON prd_versions(prd_id, version);

COMMENT ON TABLE prd_versions IS 'PRD版本历史表';
COMMENT ON COLUMN prd_versions.change_log IS '变更日志';

-- ============================================
-- 7. PRD 标签关联表 (prd_tags)
-- ============================================
CREATE TABLE IF NOT EXISTS prd_tags (
    prd_id VARCHAR(36) NOT NULL REFERENCES prd_documents(id) ON DELETE CASCADE,
    tag_id VARCHAR(36) NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (prd_id, tag_id)
);

CREATE INDEX idx_prd_tags_prd_id ON prd_tags(prd_id);
CREATE INDEX idx_prd_tags_tag_id ON prd_tags(tag_id);

COMMENT ON TABLE prd_tags IS 'PRD与标签多对多关联表';

-- ============================================
-- 8. 测试用例表 (test_cases)
-- ============================================
CREATE TABLE IF NOT EXISTS test_cases (
    id VARCHAR(36) PRIMARY KEY,
    project_id VARCHAR(36) NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    app_version_id VARCHAR(36) NOT NULL REFERENCES app_versions(id) ON DELETE RESTRICT,
    code VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    prd_id VARCHAR(36) REFERENCES prd_documents(id) ON DELETE SET NULL,
    module_id VARCHAR(36) REFERENCES modules(id) ON DELETE SET NULL,
    precondition TEXT,
    expected_result TEXT NOT NULL,
    priority VARCHAR(10) NOT NULL DEFAULT 'P2',
    type VARCHAR(50) NOT NULL DEFAULT 'functional',
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    version INT NOT NULL DEFAULT 1,
    synced_to_vector BOOLEAN DEFAULT FALSE,
    sync_status VARCHAR(20),
    last_synced_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_test_cases_project_id ON test_cases(project_id);
CREATE INDEX idx_test_cases_app_version_id ON test_cases(app_version_id);
CREATE INDEX idx_test_cases_prd_id ON test_cases(prd_id);
CREATE INDEX idx_test_cases_module_id ON test_cases(module_id);
CREATE INDEX idx_test_cases_priority ON test_cases(priority);
CREATE INDEX idx_test_cases_type ON test_cases(type);
CREATE INDEX idx_test_cases_status ON test_cases(status);
CREATE INDEX idx_test_cases_deleted_at ON test_cases(deleted_at);
CREATE INDEX idx_test_cases_code ON test_cases(code);
CREATE INDEX idx_test_cases_sync_status ON test_cases(sync_status);
CREATE UNIQUE INDEX idx_test_cases_project_code ON test_cases(project_id, code) WHERE deleted_at IS NULL;

COMMENT ON TABLE test_cases IS '测试用例表';
COMMENT ON COLUMN test_cases.priority IS '优先级: high-高, medium-中, low-低';
COMMENT ON COLUMN test_cases.type IS '类型: functional-功能, performance-性能, security-安全, ui-界面';
COMMENT ON COLUMN test_cases.status IS '状态: active-有效, deprecated-已废弃';
COMMENT ON COLUMN test_cases.sync_status IS '同步状态: syncing-同步中, synced-已同步, failed-失败';

-- ============================================
-- 9. 测试步骤表 (test_steps)
-- ============================================
CREATE TABLE IF NOT EXISTS test_steps (
    id VARCHAR(36) PRIMARY KEY,
    test_case_id VARCHAR(36) NOT NULL REFERENCES test_cases(id) ON DELETE CASCADE,
    step_order INT NOT NULL,
    description TEXT NOT NULL,
    test_data TEXT,
    expected TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_test_steps_test_case_id ON test_steps(test_case_id);
CREATE INDEX idx_test_steps_order ON test_steps(test_case_id, step_order);

COMMENT ON TABLE test_steps IS '测试步骤表';
COMMENT ON COLUMN test_steps.step_order IS '步骤序号';
COMMENT ON COLUMN test_steps.description IS '操作描述';
COMMENT ON COLUMN test_steps.test_data IS '测试数据';
COMMENT ON COLUMN test_steps.expected IS '该步骤的预期结果';

-- ============================================
-- 10. 测试步骤截图表 (test_step_screenshots)
-- ============================================
CREATE TABLE IF NOT EXISTS test_step_screenshots (
    id VARCHAR(36) PRIMARY KEY,
    test_step_id VARCHAR(36) NOT NULL REFERENCES test_steps(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_url VARCHAR(500) NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_test_step_screenshots_test_step_id ON test_step_screenshots(test_step_id);
CREATE INDEX idx_test_step_screenshots_sort_order ON test_step_screenshots(sort_order);

COMMENT ON TABLE test_step_screenshots IS '测试步骤截图表';
COMMENT ON COLUMN test_step_screenshots.file_url IS '文件访问URL';

-- ============================================
-- 11. 测试用例标签关联表 (test_case_tags)
-- ============================================
CREATE TABLE IF NOT EXISTS test_case_tags (
    test_case_id VARCHAR(36) NOT NULL REFERENCES test_cases(id) ON DELETE CASCADE,
    tag_id VARCHAR(36) NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (test_case_id, tag_id)
);

CREATE INDEX idx_test_case_tags_test_case_id ON test_case_tags(test_case_id);
CREATE INDEX idx_test_case_tags_tag_id ON test_case_tags(tag_id);

COMMENT ON TABLE test_case_tags IS '测试用例与标签多对多关联表';

-- ============================================
-- 12. 测试用例版本历史表 (test_case_versions)
-- ============================================
CREATE TABLE IF NOT EXISTS test_case_versions (
    id VARCHAR(36) PRIMARY KEY,
    test_case_id VARCHAR(36) NOT NULL REFERENCES test_cases(id) ON DELETE CASCADE,
    version INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    precondition TEXT,
    expected_result TEXT NOT NULL,
    priority VARCHAR(10) NOT NULL,
    type VARCHAR(50) NOT NULL,
    change_log TEXT,
    snapshot JSONB NOT NULL,
    created_by VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_test_case_versions_test_case_id ON test_case_versions(test_case_id);
CREATE INDEX idx_test_case_versions_version ON test_case_versions(version);
CREATE UNIQUE INDEX idx_test_case_versions_case_version ON test_case_versions(test_case_id, version);

COMMENT ON TABLE test_case_versions IS '测试用例版本历史表';
COMMENT ON COLUMN test_case_versions.snapshot IS '完整的用例快照（JSON格式，包含步骤等）';

-- ============================================
-- 13. 系统配置表 (system_settings)
-- ============================================
CREATE TABLE IF NOT EXISTS system_settings (
    id VARCHAR(36) PRIMARY KEY,
    project_id VARCHAR(36) NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    setting_key VARCHAR(100) NOT NULL,
    setting_value TEXT,
    setting_type VARCHAR(50) NOT NULL DEFAULT 'string',
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_system_settings_project_id ON system_settings(project_id);
CREATE INDEX idx_system_settings_key ON system_settings(setting_key);
CREATE UNIQUE INDEX idx_system_settings_project_key ON system_settings(project_id, setting_key);

COMMENT ON TABLE system_settings IS '系统配置表（存储LLM配置等）';
COMMENT ON COLUMN system_settings.setting_type IS '配置类型: string, number, boolean, json';

-- ============================================
-- 14. 全局配置表 (global_settings)
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

-- ============================================
-- 插入初始数据
-- ============================================

-- 插入示例项目
INSERT INTO projects (id, name, description, created_at) VALUES
('proj-1', '电商平台', '电商平台核心功能开发', '2025-01-01 00:00:00')
ON CONFLICT (id) DO NOTHING;

-- 插入 App 版本
INSERT INTO app_versions (id, project_id, version, description, created_at) VALUES
('v1', 'proj-1', 'v1.0.0', '初始版本 - 基础功能', '2025-01-01 00:00:00'),
('v2', 'proj-1', 'v1.1.0', '功能优化版本', '2025-01-10 00:00:00'),
('v3', 'proj-1', 'v2.0.0', '架构升级版本', '2025-01-15 00:00:00')
ON CONFLICT (id) DO NOTHING;

-- 插入模块（树形结构）
INSERT INTO modules (id, project_id, name, parent_id, sort_order, created_at) VALUES
('1', 'proj-1', '用户管理', NULL, 1, '2025-01-01 00:00:00'),
('1-1', 'proj-1', '用户注册', '1', 1, '2025-01-01 00:00:00'),
('1-2', 'proj-1', '用户登录', '1', 2, '2025-01-01 00:00:00'),
('1-3', 'proj-1', '个人资料', '1', 3, '2025-01-01 00:00:00'),
('2', 'proj-1', '订单管理', NULL, 2, '2025-01-01 00:00:00'),
('2-1', 'proj-1', '创建订单', '2', 1, '2025-01-01 00:00:00'),
('2-2', 'proj-1', '订单支付', '2', 2, '2025-01-01 00:00:00'),
('2-3', 'proj-1', '订单查询', '2', 3, '2025-01-01 00:00:00'),
('3', 'proj-1', '商品管理', NULL, 3, '2025-01-01 00:00:00'),
('3-1', 'proj-1', '商品列表', '3', 1, '2025-01-01 00:00:00'),
('3-2', 'proj-1', '商品详情', '3', 2, '2025-01-01 00:00:00'),
('3-3', 'proj-1', '商品搜索', '3', 3, '2025-01-01 00:00:00')
ON CONFLICT (id) DO NOTHING;

-- 插入标签
INSERT INTO tags (id, project_id, name, color, created_at) VALUES
('1', 'proj-1', '核心功能', 'red', '2025-01-01 00:00:00'),
('2', 'proj-1', '高优先级', 'orange', '2025-01-01 00:00:00'),
('3', 'proj-1', '需求变更', 'blue', '2025-01-01 00:00:00'),
('4', 'proj-1', 'Bug修复', 'green', '2025-01-01 00:00:00'),
('5', 'proj-1', '性能优化', 'purple', '2025-01-01 00:00:00'),
('6', 'proj-1', '安全相关', 'volcano', '2025-01-01 00:00:00')
ON CONFLICT (id) DO NOTHING;

-- 插入全局配置（Embedding API 配置）
-- 注意：请在部署后通过管理界面或环境变量设置真实的 API Key
INSERT INTO global_settings (id, key, value, type, description, created_at) VALUES
('gs-1', 'embedding_provider', 'volcano_ark', 'string', 'Embedding 服务提供商: mock, openai, volcano_ark', '2025-01-01 00:00:00'),
('gs-2', 'embedding_api_key', 'YOUR_API_KEY_HERE', 'string', 'Embedding API Key（请替换为真实的 API Key）', '2025-01-01 00:00:00'),
('gs-3', 'embedding_base_url', 'https://ark.cn-beijing.volces.com', 'string', 'Embedding API Base URL', '2025-01-01 00:00:00'),
('gs-4', 'embedding_model', 'ep-20260121110525-5mmss', 'string', 'Embedding 模型名称', '2025-01-01 00:00:00')
ON CONFLICT (key) DO NOTHING;

-- ============================================
-- 创建更新时间自动更新触发器
-- ============================================

-- 创建触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为需要的表添加触发器
CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_versions_updated_at BEFORE UPDATE ON app_versions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_modules_updated_at BEFORE UPDATE ON modules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tags_updated_at BEFORE UPDATE ON tags
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_prd_documents_updated_at BEFORE UPDATE ON prd_documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_test_cases_updated_at BEFORE UPDATE ON test_cases
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_test_steps_updated_at BEFORE UPDATE ON test_steps
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_settings_updated_at BEFORE UPDATE ON system_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_global_settings_updated_at BEFORE UPDATE ON global_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 完成
-- ============================================
-- 数据库结构创建完成
-- 包含 14 张表，完全覆盖前端所有功能
-- 支持：项目管理、App版本、模块树、标签、PRD文档、测试用例、文件上传、版本历史、系统配置、全局配置
