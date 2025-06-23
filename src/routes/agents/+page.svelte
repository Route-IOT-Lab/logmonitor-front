<script lang="ts">
	import { onMount } from 'svelte';
	import { getAgents, createAgent, updateAgent, deleteAgent, connectAgent, disconnectAgent } from '$lib/services/api';
	import type { AgentDetailView, AddAgentRequest } from '$lib/types';

	let agents: AgentDetailView[] = [];
	let loading = true;
	let showAddModal = false;
	let editingAgent: AgentDetailView | null = null;

	// 表单数据
	let formData: AddAgentRequest = {
		name: '',
		host: '',
		port: 12315,
		enabled: true,
		tags: [],
		description: '',
		useTls: false,
		apiKey: ''
	};

	let tagInput = '';

	onMount(async () => {
		await loadAgents();
		// 每30秒刷新一次
		const interval = setInterval(loadAgents, 30000);
		return () => clearInterval(interval);
	});

	async function loadAgents() {
		try {
			agents = await getAgents();
		} catch (error) {
			console.error('Failed to load agents:', error);
		} finally {
			loading = false;
		}
	}

	function openAddModal() {
		resetForm();
		showAddModal = true;
		editingAgent = null;
	}

	function openEditModal(agent: AgentDetailView) {
		formData = {
			name: agent.agent.name,
			host: agent.agent.host,
			port: agent.agent.port,
			enabled: agent.agent.enabled,
			tags: [...agent.agent.tags],
			description: agent.agent.description || '',
			useTls: agent.agent.useTls,
			apiKey: agent.agent.apiKey || ''
		};
		tagInput = '';
		showAddModal = true;
		editingAgent = agent;
	}

	function closeModal() {
		showAddModal = false;
		editingAgent = null;
		resetForm();
	}

	function resetForm() {
		formData = {
			name: '',
			host: '',
			port: 12315,
			enabled: true,
			tags: [],
			description: '',
			useTls: false,
			apiKey: ''
		};
		tagInput = '';
	}

	function addTag() {
		if (tagInput.trim() && !formData.tags.includes(tagInput.trim())) {
			formData.tags = [...formData.tags, tagInput.trim()];
			tagInput = '';
		}
	}

	function removeTag(tag: string) {
		formData.tags = formData.tags.filter(t => t !== tag);
	}

	async function handleSubmit() {
		try {
			if (editingAgent) {
				await updateAgent(editingAgent.agent.id, formData);
			} else {
				await createAgent(formData);
			}
			await loadAgents();
			closeModal();
		} catch (error) {
			console.error('Failed to save agent:', error);
		}
	}

	async function handleDelete(agent: AgentDetailView) {
		if (confirm(`确定要删除 Agent "${agent.agent.name}" 吗？`)) {
			try {
				await deleteAgent(agent.agent.id);
				await loadAgents();
			} catch (error) {
				console.error('Failed to delete agent:', error);
			}
		}
	}

	async function handleConnect(agent: AgentDetailView) {
		try {
			if (agent.isConnected) {
				await disconnectAgent(agent.agent.id);
			} else {
				await connectAgent(agent.agent.id);
			}
			await loadAgents();
		} catch (error) {
			console.error('Failed to toggle agent connection:', error);
		}
	}
</script>

<svelte:head>
	<title>Agent 管理 - 日志监控系统</title>
</svelte:head>

<div class="container">
	<header>
		<h1>📋 Agent 管理</h1>
		<button class="btn btn-primary" on:click={openAddModal}>
			➕ 添加 Agent
		</button>
	</header>

	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>加载 Agents 中...</p>
		</div>
	{:else if agents.length === 0}
		<div class="empty">
			<h2>🤖 暂无 Agent</h2>
			<p>点击上方按钮添加第一个 Agent</p>
		</div>
	{:else}
		<div class="agents-grid">
			{#each agents as agent}
				<div class="agent-card">
					<div class="agent-header">
						<h3>{agent.agent.name}</h3>
						<div class="agent-status">
							<span class="status-dot {agent.isConnected ? 'connected' : 'disconnected'}"></span>
							<span class="status-text {agent.isConnected ? 'status-connected' : 'status-disconnected'}">
								{agent.isConnected ? '已连接' : '未连接'}
							</span>
						</div>
					</div>

					<div class="agent-info">
						<p><strong>地址:</strong> {agent.agent.host}:{agent.agent.port}</p>
						<p><strong>协议:</strong> {agent.agent.useTls ? 'WSS' : 'WS'}</p>
						<p><strong>状态:</strong> {agent.agent.enabled ? '启用' : '禁用'}</p>
						{#if agent.agent.description}
							<p><strong>描述:</strong> {agent.agent.description}</p>
						{/if}
					</div>

					{#if agent.agent.tags.length > 0}
						<div class="tags">
							{#each agent.agent.tags as tag}
								<span class="tag">{tag}</span>
							{/each}
						</div>
					{/if}

					<div class="agent-stats">
						<div class="stat">
							<span class="stat-value">{agent.logFiles.length}</span>
							<span class="stat-label">日志文件</span>
						</div>
						<div class="stat">
							<span class="stat-value">{agent.monitoringCount}</span>
							<span class="stat-label">监控中</span>
						</div>
					</div>

					<div class="agent-actions">
						<button 
							class="btn btn-secondary"
							on:click={() => handleConnect(agent)}
						>
							{agent.isConnected ? '🔌 断开' : '🔗 连接'}
						</button>
						<button 
							class="btn btn-secondary"
							on:click={() => openEditModal(agent)}
						>
							✏️ 编辑
						</button>
						<a href="/logs/{agent.agent.id}" class="btn btn-secondary">
							📄 日志
						</a>
						<button 
							class="btn btn-danger"
							on:click={() => handleDelete(agent)}
						>
							🗑️ 删除
						</button>
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

<!-- 添加/编辑 Modal -->
{#if showAddModal}
	<div class="modal" on:click={closeModal} on:keydown={(e) => e.key === 'Escape' && closeModal()} role="dialog" aria-modal="true">
		<div class="modal-content" on:click|stopPropagation on:keydown={(e) => e.stopPropagation()} role="document">
			<h2>{editingAgent ? '编辑 Agent' : '添加 Agent'}</h2>
			
			<form on:submit|preventDefault={handleSubmit}>
				<div class="form-group">
					<label for="name">名称 *</label>
					<input 
						id="name"
						type="text" 
						class="input" 
						bind:value={formData.name} 
						required 
						placeholder="Agent 名称"
					/>
				</div>

				<div class="form-row">
					<div class="form-group">
						<label for="host">主机地址 *</label>
						<input 
							id="host"
							type="text" 
							class="input" 
							bind:value={formData.host} 
							required 
							placeholder="127.0.0.1"
						/>
					</div>
					<div class="form-group">
						<label for="port">端口 *</label>
						<input 
							id="port"
							type="number" 
							class="input" 
							bind:value={formData.port} 
							required 
							min="1"
							max="65535"
						/>
					</div>
				</div>

				<div class="form-group">
					<label for="description">描述</label>
					<textarea 
						id="description"
						class="input" 
						bind:value={formData.description} 
						placeholder="Agent 描述信息"
						rows="3"
					></textarea>
				</div>

				<div class="form-group">
					<label for="tags">标签</label>
					<div class="tag-input">
						<input 
							type="text" 
							class="input" 
							bind:value={tagInput}
							placeholder="输入标签后按回车添加"
							on:keydown={(e) => e.key === 'Enter' && (e.preventDefault(), addTag())}
						/>
						<button type="button" class="btn btn-secondary" on:click={addTag}>
							添加
						</button>
					</div>
					{#if formData.tags.length > 0}
						<div class="tags">
							{#each formData.tags as tag}
								<span class="tag">
									{tag}
									<button type="button" on:click={() => removeTag(tag)}>×</button>
								</span>
							{/each}
						</div>
					{/if}
				</div>

				<div class="form-group">
					<label for="apiKey">API 密钥</label>
					<input 
						id="apiKey"
						type="password" 
						class="input" 
						bind:value={formData.apiKey} 
						placeholder="可选的 API 密钥"
					/>
				</div>

				<div class="form-row">
					<div class="checkbox-group">
						<label class="checkbox-label">
							<input type="checkbox" bind:checked={formData.enabled} />
							启用 Agent
						</label>
					</div>
					<div class="checkbox-group">
						<label class="checkbox-label">
							<input type="checkbox" bind:checked={formData.useTls} />
							使用 TLS (WSS)
						</label>
					</div>
				</div>

				<div class="form-actions">
					<button type="button" class="btn btn-secondary" on:click={closeModal}>
						取消
					</button>
					<button type="submit" class="btn btn-primary">
						{editingAgent ? '更新' : '创建'} Agent
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

<style>
	.container {
		max-width: 1200px;
		margin: 0 auto;
		padding: 2rem;
	}

	header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 2rem;
	}

	header h1 {
		margin: 0;
		font-size: 2rem;
	}

	.loading, .empty {
		text-align: center;
		padding: 3rem;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid rgba(255, 255, 255, 0.3);
		border-left: 4px solid #667eea;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin: 0 auto 1rem;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.agents-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
		gap: 1.5rem;
	}

	.agent-card {
		background: rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		border: 1px solid rgba(255, 255, 255, 0.2);
		backdrop-filter: blur(10px);
		padding: 1.5rem;
		transition: transform 0.2s;
	}

	.agent-card:hover {
		transform: translateY(-2px);
	}

	.agent-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.agent-header h3 {
		margin: 0;
		font-size: 1.2rem;
	}

	.agent-status {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.status-dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
	}

	.status-dot.connected {
		background: #4ade80;
	}

	.status-dot.disconnected {
		background: #f87171;
	}

	.status-text {
		font-size: 0.875rem;
		font-weight: 500;
	}

	.agent-info {
		margin-bottom: 1rem;
	}

	.agent-info p {
		margin: 0.25rem 0;
		font-size: 0.875rem;
	}

	.tags {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	.tag {
		background: rgba(102, 126, 234, 0.2);
		color: #667eea;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		font-size: 0.75rem;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.tag button {
		background: none;
		border: none;
		color: inherit;
		cursor: pointer;
		padding: 0;
		width: 16px;
		height: 16px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.tag button:hover {
		background: rgba(255, 255, 255, 0.2);
	}

	.agent-stats {
		display: flex;
		gap: 1rem;
		margin-bottom: 1rem;
		padding: 1rem;
		background: rgba(0, 0, 0, 0.2);
		border-radius: 8px;
	}

	.stat {
		text-align: center;
	}

	.stat-value {
		display: block;
		font-size: 1.5rem;
		font-weight: bold;
		color: #667eea;
	}

	.stat-label {
		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.7);
	}

	.agent-actions {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.agent-actions .btn {
		flex: 1;
		min-width: 80px;
		font-size: 0.875rem;
		padding: 0.5rem;
	}

	.form-group {
		margin-bottom: 1rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 500;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
	}

	.tag-input {
		display: flex;
		gap: 0.5rem;
	}

	.tag-input input {
		flex: 1;
	}

	.checkbox-group {
		display: flex;
		align-items: center;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
	}

	.form-actions {
		display: flex;
		gap: 1rem;
		justify-content: flex-end;
		margin-top: 2rem;
	}

	textarea.input {
		resize: vertical;
		min-height: 80px;
	}

	@media (max-width: 768px) {
		.container {
			padding: 1rem;
		}

		header {
			flex-direction: column;
			gap: 1rem;
			align-items: stretch;
		}

		.agents-grid {
			grid-template-columns: 1fr;
		}

		.form-row {
			grid-template-columns: 1fr;
		}

		.agent-actions {
			flex-direction: column;
		}

		.agent-actions .btn {
			flex: none;
		}
	}
</style>
