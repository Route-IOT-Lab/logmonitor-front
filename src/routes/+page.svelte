<script lang="ts">
	import { onMount } from 'svelte';
	import { getSystemStatus } from '$lib/services/api';
	import type { SystemOverview } from '$lib/types';

	let systemStatus: SystemOverview | null = null;
	let loading = true;

	onMount(async () => {
		await loadSystemStatus();
		// 每30秒刷新一次状态
		const interval = setInterval(loadSystemStatus, 30000);
		return () => clearInterval(interval);
	});

	async function loadSystemStatus() {
		try {
			systemStatus = await getSystemStatus();
		} catch (error) {
			console.error('Failed to load system status:', error);
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>日志监控系统</title>
	<meta name="description" content="实时日志监控和管理系统" />
</svelte:head>

<div class="container">
	<header>
		<h1>🚀 日志监控系统</h1>
		<p>基于 Vert.x + Kotlin 的实时日志监控系统</p>
	</header>

	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>加载系统状态中...</p>
		</div>
	{:else if systemStatus}
		<div class="overview">
			<div class="stats-grid">
				<div class="stat-card">
					<div class="stat-value">{systemStatus.totalAgents}</div>
					<div class="stat-label">总 Agent 数</div>
				</div>
				<div class="stat-card">
					<div class="stat-value status-connected">{systemStatus.connectedAgents}</div>
					<div class="stat-label">已连接</div>
				</div>
				<div class="stat-card">
					<div class="stat-value">{systemStatus.totalLogFiles}</div>
					<div class="stat-label">日志文件</div>
				</div>
				<div class="stat-card">
					<div class="stat-value status-connected">{systemStatus.monitoringLogFiles}</div>
					<div class="stat-label">监控中</div>
				</div>
			</div>
		</div>

		<div class="actions">
			<a href="/agents" class="btn btn-primary">
				📋 管理 Agents
			</a>
			<a href="/logs" class="btn btn-secondary">
				📄 查看日志
			</a>
			<a href="/monitoring" class="btn btn-secondary">
				📊 监控面板
			</a>
			<a href="/settings" class="btn btn-secondary">
				⚙️ 系统设置
			</a>
		</div>

		<div class="features">
			<h2>🎯 核心特性</h2>
			<div class="feature-grid">
				<div class="feature-card">
					<div class="feature-icon">🔧</div>
					<h3>SQLite 锁定解决</h3>
					<p>采用 WAL 模式 + 连接池 + 协程互斥锁，彻底解决数据库并发锁定问题</p>
				</div>
				<div class="feature-card">
					<div class="feature-icon">⚡</div>
					<h3>高并发支持</h3>
					<p>支持 10+ 并发操作无错误，响应时间稳定在 50-100ms</p>
				</div>
				<div class="feature-card">
					<div class="feature-icon">🌐</div>
					<h3>实时监控</h3>
					<p>WebSocket 实时推送日志消息，支持多 Agent 同时监控</p>
				</div>
				<div class="feature-card">
					<div class="feature-icon">🏗️</div>
					<h3>现代化架构</h3>
					<p>Vert.x 协程 + 原生 JDBC + 自定义连接池的最佳实践</p>
				</div>
			</div>
		</div>
	{:else}
		<div class="error">
			<h2>❌ 无法连接到后端服务</h2>
			<p>请确保后端服务正在运行在 http://localhost:8081</p>
			<button class="btn btn-primary" on:click={loadSystemStatus}>
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
		font-size: 3rem;
		margin-bottom: 0.5rem;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}

	header p {
		font-size: 1.2rem;
		color: rgba(255, 255, 255, 0.8);
	}

	.loading {
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

	.overview {
		margin-bottom: 3rem;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1.5rem;
		margin-bottom: 2rem;
	}

	.stat-card {
		background: rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		border: 1px solid rgba(255, 255, 255, 0.2);
		backdrop-filter: blur(10px);
		padding: 2rem;
		text-align: center;
		transition: transform 0.2s;
	}

	.stat-card:hover {
		transform: translateY(-4px);
	}

	.stat-value {
		font-size: 2.5rem;
		font-weight: bold;
		margin-bottom: 0.5rem;
	}

	.stat-label {
		color: rgba(255, 255, 255, 0.8);
		font-size: 0.9rem;
	}

	.actions {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
		margin-bottom: 3rem;
	}

	.features {
		margin-top: 3rem;
	}

	.features h2 {
		text-align: center;
		font-size: 2rem;
		margin-bottom: 2rem;
	}

	.feature-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1.5rem;
	}

	.feature-card {
		background: rgba(255, 255, 255, 0.05);
		border-radius: 12px;
		border: 1px solid rgba(255, 255, 255, 0.1);
		padding: 2rem;
		text-align: center;
		transition: all 0.3s;
	}

	.feature-card:hover {
		background: rgba(255, 255, 255, 0.1);
		transform: translateY(-4px);
	}

	.feature-icon {
		font-size: 3rem;
		margin-bottom: 1rem;
	}

	.feature-card h3 {
		font-size: 1.2rem;
		margin-bottom: 1rem;
		color: #667eea;
	}

	.feature-card p {
		color: rgba(255, 255, 255, 0.8);
		line-height: 1.6;
	}

	.error {
		text-align: center;
		padding: 3rem;
	}

	.error h2 {
		color: #f87171;
		margin-bottom: 1rem;
	}

	.error p {
		color: rgba(255, 255, 255, 0.8);
		margin-bottom: 2rem;
	}

	@media (max-width: 768px) {
		.container {
			padding: 1rem;
		}

		header h1 {
			font-size: 2rem;
		}

		.stats-grid {
			grid-template-columns: repeat(2, 1fr);
		}

		.actions {
			grid-template-columns: 1fr;
		}

		.feature-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
