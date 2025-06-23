<script lang="ts">
	import { onMount } from 'svelte';
	import { getSystemStatus, getAgents } from '$lib/services/api';
	import type { SystemOverview, AgentDetailView } from '$lib/types';

	let systemStatus: SystemOverview | null = null;
	let agents: AgentDetailView[] = [];
	let loading = true;

	onMount(async () => {
		await loadData();
		// 每10秒刷新一次
		const interval = setInterval(loadData, 10000);
		return () => clearInterval(interval);
	});

	async function loadData() {
		try {
			const [status, agentList] = await Promise.all([
				getSystemStatus(),
				getAgents()
			]);
			systemStatus = status;
			agents = agentList;
		} catch (error) {
			console.error('Failed to load monitoring data:', error);
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>监控面板 - 日志监控系统</title>
</svelte:head>

<div class="container">
	<header>
		<h1>📊 监控面板</h1>
		<p>实时系统状态监控</p>
	</header>

	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>加载监控数据中...</p>
		</div>
	{:else if systemStatus}
		<div class="monitoring-grid">
			<!-- 系统概览 -->
			<div class="panel">
				<h2>🚀 系统概览</h2>
				<div class="stats-grid">
					<div class="stat-item">
						<div class="stat-value">{systemStatus.totalAgents}</div>
						<div class="stat-label">总 Agents</div>
					</div>
					<div class="stat-item">
						<div class="stat-value status-connected">{systemStatus.connectedAgents}</div>
						<div class="stat-label">已连接</div>
					</div>
					<div class="stat-item">
						<div class="stat-value">{systemStatus.totalLogFiles}</div>
						<div class="stat-label">日志文件</div>
					</div>
					<div class="stat-item">
						<div class="stat-value status-connected">{systemStatus.monitoringLogFiles}</div>
						<div class="stat-label">监控中</div>
					</div>
				</div>
			</div>

			<!-- Agent 状态 -->
			<div class="panel">
				<h2>🤖 Agent 状态</h2>
				<div class="agent-status-list">
					{#each agents as agent}
						<div class="agent-status-item">
							<div class="agent-info">
								<span class="agent-name">{agent.agent.name}</span>
								<span class="agent-address">{agent.agent.host}:{agent.agent.port}</span>
							</div>
							<div class="status-indicator">
								<span class="status-dot {agent.isConnected ? 'connected' : 'disconnected'}"></span>
								<span class="status-text {agent.isConnected ? 'status-connected' : 'status-disconnected'}">
									{agent.isConnected ? '在线' : '离线'}
								</span>
							</div>
						</div>
					{/each}
				</div>
			</div>

			<!-- 实时状态 -->
			<div class="panel">
				<h2>⚡ 实时状态</h2>
				<div class="realtime-stats">
					<div class="realtime-item">
						<span class="realtime-label">连接率:</span>
						<span class="realtime-value">
							{systemStatus.totalAgents > 0 ? Math.round((systemStatus.connectedAgents / systemStatus.totalAgents) * 100) : 0}%
						</span>
					</div>
					<div class="realtime-item">
						<span class="realtime-label">监控率:</span>
						<span class="realtime-value">
							{systemStatus.totalLogFiles > 0 ? Math.round((systemStatus.monitoringLogFiles / systemStatus.totalLogFiles) * 100) : 0}%
						</span>
					</div>
					<div class="realtime-item">
						<span class="realtime-label">最后更新:</span>
						<span class="realtime-value">{new Date().toLocaleTimeString()}</span>
					</div>
				</div>
			</div>
		</div>
	{:else}
		<div class="error">
			<h2>❌ 无法加载监控数据</h2>
			<p>请确保后端服务正在运行</p>
			<button class="btn btn-primary" on:click={loadData}>
				🔄 重试
			</button>
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

	.loading, .error {
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

	.monitoring-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 1.5rem;
	}

	.panel {
		background: rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		border: 1px solid rgba(255, 255, 255, 0.2);
		backdrop-filter: blur(10px);
		padding: 1.5rem;
	}

	.panel h2 {
		margin: 0 0 1rem 0;
		font-size: 1.2rem;
		color: #667eea;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
	}

	.stat-item {
		text-align: center;
		padding: 1rem;
		background: rgba(0, 0, 0, 0.2);
		border-radius: 8px;
	}

	.stat-value {
		font-size: 2rem;
		font-weight: bold;
		margin-bottom: 0.25rem;
	}

	.stat-label {
		font-size: 0.875rem;
		color: rgba(255, 255, 255, 0.7);
	}

	.agent-status-list {
		space-y: 0.5rem;
	}

	.agent-status-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem;
		background: rgba(0, 0, 0, 0.2);
		border-radius: 8px;
		margin-bottom: 0.5rem;
	}

	.agent-info {
		display: flex;
		flex-direction: column;
	}

	.agent-name {
		font-weight: 500;
	}

	.agent-address {
		font-size: 0.875rem;
		color: rgba(255, 255, 255, 0.7);
		font-family: var(--font-mono);
	}

	.status-indicator {
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

	.realtime-stats {
		space-y: 0.75rem;
	}

	.realtime-item {
		display: flex;
		justify-content: space-between;
		padding: 0.75rem;
		background: rgba(0, 0, 0, 0.2);
		border-radius: 8px;
		margin-bottom: 0.75rem;
	}

	.realtime-label {
		color: rgba(255, 255, 255, 0.8);
	}

	.realtime-value {
		font-weight: 500;
		color: #667eea;
	}

	@media (max-width: 768px) {
		.container {
			padding: 1rem;
		}

		.monitoring-grid {
			grid-template-columns: 1fr;
		}

		.stats-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
