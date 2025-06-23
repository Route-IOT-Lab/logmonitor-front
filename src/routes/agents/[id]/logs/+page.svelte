<script lang="ts">
	import { page } from '$app/stores';
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { 
		getAgent, 
		getLogFiles, 
		getLogFileTail
	} from '$lib/services/api';
	import { webSocketService } from '$lib/services/websocket';
	import type { AgentDetailView, LogFile, LogMessage } from '$lib/types';

	let agentId: number;
	let agent: AgentDetailView | null = null;
	let logFiles: LogFile[] = [];
	let selectedLogFile: LogFile | null = null;
	let logMessages: LogMessage[] = [];
	let loading = true;
	let logsLoading = false;
	let autoRefresh = true;
	let refreshInterval: NodeJS.Timeout | null = null;

	// 日志查看参数
	let logLimit = 100;
	let logLevelFilter = 'all';
	let searchQuery = '';

	$: agentId = parseInt($page.params.id);

	onMount(async () => {
		await loadAgent();
		await loadLogFiles();
		
		// 连接WebSocket
		if (!webSocketService.isConnected()) {
			try {
				await webSocketService.connect();
			} catch (error) {
				console.error('Failed to connect WebSocket:', error);
			}
		}

		// 订阅实时日志
		webSocketService.subscribe('log', handleLogMessage);
		
		// 开始自动刷新
		if (autoRefresh) {
			startAutoRefresh();
		}
	});

	onDestroy(() => {
		// 清理WebSocket订阅
		webSocketService.unsubscribe('log', handleLogMessage);
		
		// 停止自动刷新
		if (refreshInterval) {
			clearInterval(refreshInterval);
		}
	});

	async function loadAgent() {
		try {
			agent = await getAgent(agentId);
			if (!agent) {
				goto('/agents');
				return;
			}
		} catch (error) {
			console.error('Failed to load agent:', error);
			goto('/agents');
		} finally {
			loading = false;
		}
	}

	async function loadLogFiles() {
		try {
			logFiles = await getLogFiles(agentId);
			// 如果有日志文件且没有选中的，默认选中第一个
			if (logFiles.length > 0 && !selectedLogFile) {
				selectedLogFile = logFiles[0];
				await loadLogs();
			}
		} catch (error) {
			console.error('Failed to load log files:', error);
		}
	}

	async function loadLogs() {
		if (!selectedLogFile) return;
		
		logsLoading = true;
		try {
			logMessages = await getLogFileTail(agentId, selectedLogFile.alias, logLimit);
		} catch (error) {
			console.error('Failed to load logs:', error);
		} finally {
			logsLoading = false;
		}
	}

	function handleLogMessage(data: any) {
		if (data.agentId === agentId && selectedLogFile && data.logFileAlias === selectedLogFile.alias) {
			// 添加新的日志消息到顶部
			logMessages = [data, ...logMessages.slice(0, logLimit - 1)];
		}
	}

	function startAutoRefresh() {
		refreshInterval = setInterval(() => {
			if (selectedLogFile && !logsLoading) {
				loadLogs();
			}
		}, 5000); // 每5秒刷新一次
	}

	function stopAutoRefresh() {
		if (refreshInterval) {
			clearInterval(refreshInterval);
			refreshInterval = null;
		}
	}

	function toggleAutoRefresh() {
		autoRefresh = !autoRefresh;
		if (autoRefresh) {
			startAutoRefresh();
		} else {
			stopAutoRefresh();
		}
	}

	async function selectLogFile(logFile: LogFile) {
		selectedLogFile = logFile;
		await loadLogs();
	}

	function getLogLevelClass(level: string): string {
		switch (level.toLowerCase()) {
			case 'error': return 'error';
			case 'warn': case 'warning': return 'warn';
			case 'info': return 'info';
			case 'debug': return 'debug';
			default: return '';
		}
	}

	function formatTimestamp(timestamp: string): string {
		return new Date(timestamp).toLocaleString();
	}

	// 过滤日志消息
	$: filteredLogMessages = logMessages.filter(message => {
		// 级别过滤
		if (logLevelFilter !== 'all' && message.level.toLowerCase() !== logLevelFilter) {
			return false;
		}
		
		// 搜索过滤
		if (searchQuery && !message.content.toLowerCase().includes(searchQuery.toLowerCase())) {
			return false;
		}
		
		return true;
	});
</script>

<svelte:head>
	<title>日志查看 - {agent?.agent.name || 'Loading'}</title>
</svelte:head>

<div class="container">
	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>加载Agent信息中...</p>
		</div>
	{:else if agent}
		<!-- 头部导航 -->
		<div class="header">
			<div class="breadcrumb">
				<a href="/agents">Agents</a>
				<span>›</span>
				<a href="/agents/{agentId}">{agent.agent.name}</a>
				<span>›</span>
				<span>日志查看</span>
			</div>
			<div class="header-actions">
				<a href="/agents/{agentId}" class="btn btn-secondary">← 返回详情</a>
			</div>
		</div>

		<!-- 日志查看控制 -->
		<div class="logs-controls-panel">
			<h2>📄 日志查看</h2>
			<div class="controls">
				<label>
					显示行数:
					<select bind:value={logLimit} on:change={loadLogs} class="input small">
						<option value={50}>50行</option>
						<option value={100}>100行</option>
						<option value={200}>200行</option>
						<option value={500}>500行</option>
						<option value={1000}>1000行</option>
					</select>
				</label>
				<label>
					日志级别:
					<select bind:value={logLevelFilter} class="input small">
						<option value="all">全部</option>
						<option value="error">Error</option>
						<option value="warn">Warning</option>
						<option value="info">Info</option>
						<option value="debug">Debug</option>
					</select>
				</label>
				<input 
					type="text" 
					placeholder="搜索日志内容..." 
					bind:value={searchQuery}
					class="input small search-input"
				/>
				<button 
					class="btn {autoRefresh ? 'btn-primary' : 'btn-secondary'}"
					on:click={toggleAutoRefresh}
				>
					{autoRefresh ? '🔄 自动刷新' : '⏸️ 手动刷新'}
				</button>
				<button class="btn btn-secondary" on:click={loadLogs}>
					🔄 刷新
				</button>
			</div>
		</div>

		{#if logFiles.length === 0}
			<div class="empty-state">
				<h3>📂 暂无日志文件</h3>
				<p>请先在Agent详情页面添加日志文件</p>
				<a href="/agents/{agentId}" class="btn btn-primary">
					前往添加
				</a>
			</div>
		{:else}
			<!-- 日志文件选择器 -->
			<div class="log-files-selector">
				<h3>选择日志文件:</h3>
				<div class="log-files-tabs">
					{#each logFiles as logFile}
						<button 
							class="log-file-tab {selectedLogFile?.id === logFile.id ? 'active' : ''}"
							on:click={() => selectLogFile(logFile)}
						>
							<span class="file-name">{logFile.alias}</span>
							<span class="file-status {logFile.enabled ? 'enabled' : 'disabled'}">
								{logFile.enabled ? '监控中' : '已停用'}
							</span>
						</button>
					{/each}
				</div>
			</div>

			<!-- 日志内容显示 -->
			{#if selectedLogFile}
				<div class="log-viewer">
					<div class="log-viewer-header">
						<h3>📄 {selectedLogFile.alias}</h3>
						<div class="log-stats">
							<span>显示 {filteredLogMessages.length} / {logMessages.length} 条日志</span>
							{#if logsLoading}
								<span class="loading-indicator">🔄 加载中...</span>
							{/if}
						</div>
					</div>

					<div class="log-content">
						{#if filteredLogMessages.length === 0}
							<div class="empty-logs">
								{#if logsLoading}
									<div class="spinner small"></div>
									<p>正在加载日志...</p>
								{:else}
									<p>暂无符合条件的日志数据</p>
									{#if logMessages.length > 0}
										<p>尝试调整过滤条件</p>
									{/if}
								{/if}
							</div>
						{:else}
							<div class="log-messages">
								{#each filteredLogMessages as message, index}
									<div class="log-entry {getLogLevelClass(message.level)}">
										<div class="log-line-number">{index + 1}</div>
										<div class="log-timestamp">
											{formatTimestamp(message.timestamp)}
										</div>
										<div class="log-level">[{message.level.toUpperCase()}]</div>
										<div class="log-content-text">{message.content}</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				</div>
			{:else}
				<div class="no-selection">
					<h3>请选择一个日志文件</h3>
					<p>从上方选择要查看的日志文件</p>
				</div>
			{/if}
		{/if}
	{:else}
		<div class="error">
			<h2>❌ Agent不存在</h2>
			<p>请检查Agent ID是否正确</p>
			<a href="/agents" class="btn btn-primary">返回列表</a>
		</div>
	{/if}
</div>

<style>
	.container {
		max-width: 1400px;
		margin: 0 auto;
		padding: 2rem;
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

	.spinner.small {
		width: 20px;
		height: 20px;
		border-width: 2px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 2rem;
		padding: 1rem;
		background: rgba(255, 255, 255, 0.1);
		border-radius: 8px;
		border: 1px solid rgba(255, 255, 255, 0.2);
	}

	.breadcrumb {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
	}

	.breadcrumb a {
		color: #667eea;
		text-decoration: none;
	}

	.breadcrumb a:hover {
		text-decoration: underline;
	}

	.breadcrumb span {
		color: rgba(255, 255, 255, 0.6);
	}

	.logs-controls-panel {
		background: rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		border: 1px solid rgba(255, 255, 255, 0.2);
		backdrop-filter: blur(10px);
		padding: 1.5rem;
		margin-bottom: 1.5rem;
	}

	.logs-controls-panel h2 {
		margin: 0 0 1rem 0;
		font-size: 1.2rem;
		color: #667eea;
	}

	.controls {
		display: flex;
		gap: 1rem;
		align-items: center;
		flex-wrap: wrap;
	}

	.controls label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		white-space: nowrap;
	}

	.input.small {
		width: auto;
		min-width: 80px;
		padding: 0.5rem;
		font-size: 0.875rem;
	}

	.search-input {
		min-width: 250px;
	}

	.empty-state, .no-selection {
		text-align: center;
		padding: 3rem;
		color: rgba(255, 255, 255, 0.6);
		background: rgba(255, 255, 255, 0.05);
		border-radius: 8px;
	}

	.log-files-selector {
		margin-bottom: 1.5rem;
	}

	.log-files-selector h3 {
		margin: 0 0 1rem 0;
		font-size: 1rem;
		color: rgba(255, 255, 255, 0.9);
	}

	.log-files-tabs {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.log-file-tab {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.25rem;
		padding: 0.75rem 1rem;
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
		color: white;
	}

	.log-file-tab:hover {
		background: rgba(255, 255, 255, 0.1);
	}

	.log-file-tab.active {
		background: rgba(102, 126, 234, 0.2);
		border-color: #667eea;
	}

	.file-name {
		font-weight: 500;
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

	.log-viewer {
		background: rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		border: 1px solid rgba(255, 255, 255, 0.2);
		backdrop-filter: blur(10px);
		overflow: hidden;
	}

	.log-viewer-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem 1.5rem;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
		background: rgba(0, 0, 0, 0.2);
	}

	.log-viewer-header h3 {
		margin: 0;
		font-size: 1rem;
		color: rgba(255, 255, 255, 0.9);
	}

	.log-stats {
		display: flex;
		gap: 1rem;
		font-size: 0.875rem;
		color: rgba(255, 255, 255, 0.6);
	}

	.loading-indicator {
		color: #667eea;
	}

	.log-content {
		height: 600px;
		overflow-y: auto;
		padding: 1rem;
	}

	.empty-logs {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		color: rgba(255, 255, 255, 0.6);
		gap: 1rem;
	}

	.log-messages {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.log-entry {
		display: grid;
		grid-template-columns: auto auto auto 1fr;
		gap: 0.75rem;
		padding: 0.5rem;
		border-radius: 4px;
		background: rgba(255, 255, 255, 0.05);
		border-left: 3px solid #667eea;
		font-family: var(--font-mono);
		font-size: 0.875rem;
		align-items: start;
		transition: background 0.2s;
	}

	.log-entry:hover {
		background: rgba(255, 255, 255, 0.1);
	}

	.log-entry.error {
		border-left-color: #f87171;
	}

	.log-entry.warn {
		border-left-color: #fbbf24;
	}

	.log-entry.info {
		border-left-color: #60a5fa;
	}

	.log-entry.debug {
		border-left-color: #a78bfa;
	}

	.log-line-number {
		color: rgba(255, 255, 255, 0.4);
		font-size: 0.75rem;
		width: 3rem;
		text-align: right;
		user-select: none;
	}

	.log-timestamp {
		color: rgba(255, 255, 255, 0.6);
		font-size: 0.75rem;
		white-space: nowrap;
	}

	.log-level {
		color: rgba(255, 255, 255, 0.8);
		font-weight: 500;
		font-size: 0.75rem;
		white-space: nowrap;
	}

	.log-content-text {
		word-break: break-word;
		line-height: 1.4;
	}

	@media (max-width: 768px) {
		.container {
			padding: 1rem;
		}

		.header {
			flex-direction: column;
			gap: 1rem;
			align-items: stretch;
		}

		.controls {
			flex-direction: column;
			align-items: stretch;
		}

		.controls label {
			justify-content: space-between;
		}

		.log-files-tabs {
			flex-direction: column;
		}

		.log-entry {
			grid-template-columns: 1fr;
			gap: 0.5rem;
		}

		.log-line-number {
			display: none;
		}

		.log-content {
			height: 400px;
		}
	}
</style> 