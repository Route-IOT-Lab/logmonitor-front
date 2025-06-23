<script lang="ts">
	import { onMount } from 'svelte';
	import { getAgents } from '$lib/services/api';
	import type { AgentDetailView } from '$lib/types';

	let agents: AgentDetailView[] = [];
	let loading = true;

	onMount(async () => {
		await loadAgents();
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
</script>

<svelte:head>
	<title>日志查看 - 日志监控系统</title>
</svelte:head>

<div class="container">
	<header>
		<h1>📄 日志查看</h1>
		<p>选择 Agent 查看其日志文件</p>
	</header>

	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>加载 Agents 中...</p>
		</div>
	{:else if agents.length === 0}
		<div class="empty">
			<h2>🤖 暂无 Agent</h2>
			<p>请先在 <a href="/agents">Agent 管理</a> 页面添加 Agent</p>
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
						<p><strong>日志文件:</strong> {agent.logFiles.length} 个</p>
						<p><strong>监控中:</strong> {agent.monitoringCount} 个</p>
					</div>

					{#if agent.logFiles.length > 0}
						<div class="log-files">
							<h4>日志文件:</h4>
							<div class="file-list">
								{#each agent.logFiles as logFile}
									<div class="file-item">
										<span class="file-name">{logFile.alias}</span>
										<span class="file-status {logFile.enabled ? 'enabled' : 'disabled'}">
											{logFile.enabled ? '监控中' : '已停用'}
										</span>
									</div>
								{/each}
							</div>
						</div>
					{/if}

					<div class="agent-actions">
						<a href="/agents/{agent.agent.id}" class="btn btn-primary">
							📋 查看详情
						</a>
						{#if agent.logFiles.length > 0}
							<a href="/agents/{agent.agent.id}/logs" class="btn btn-secondary">
								📄 查看日志
							</a>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.container {
		max-width: 1200px;
		margin: 0 auto;
		padding: 2rem;
	}

	header {
		text-align: center;
		margin-bottom: 3rem;
	}

	header h1 {
		font-size: 2.5rem;
		margin-bottom: 0.5rem;
	}

	header p {
		color: rgba(255, 255, 255, 0.8);
		font-size: 1.1rem;
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

	.empty a {
		color: #667eea;
		text-decoration: underline;
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

	.log-files {
		margin-bottom: 1.5rem;
	}

	.log-files h4 {
		margin: 0 0 0.5rem 0;
		font-size: 1rem;
		color: rgba(255, 255, 255, 0.9);
	}

	.file-list {
		background: rgba(0, 0, 0, 0.2);
		border-radius: 8px;
		padding: 0.75rem;
	}

	.file-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.5rem 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
	}

	.file-item:last-child {
		border-bottom: none;
	}

	.file-name {
		font-family: var(--font-mono);
		font-size: 0.875rem;
	}

	.file-status {
		font-size: 0.75rem;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		font-weight: 500;
	}

	.file-status.enabled {
		background: rgba(74, 222, 128, 0.2);
		color: #4ade80;
	}

	.file-status.disabled {
		background: rgba(248, 113, 113, 0.2);
		color: #f87171;
	}

	.agent-actions {
		display: flex;
		gap: 0.5rem;
	}

	.agent-actions .btn {
		flex: 1;
		text-align: center;
		font-size: 0.875rem;
		padding: 0.75rem;
	}

	@media (max-width: 768px) {
		.container {
			padding: 1rem;
		}

		.agents-grid {
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
