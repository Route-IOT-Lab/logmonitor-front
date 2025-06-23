<script lang="ts">
	import { page } from '$app/stores';
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { 
		getAgent, 
		getLogFiles, 
		addLogFile, 
		startLogFileMonitoring, 
		stopLogFileMonitoring,
		getLogMessages,
		getLogFileTail
	} from '$lib/services/api';
	import { webSocketService } from '$lib/services/websocket';
	import type { AgentDetailView, LogFile, LogMessage, AddLogFileRequest } from '$lib/types';

	let agentId: number;
	let agent: AgentDetailView | null = null;
	let logFiles: LogFile[] = [];
	let selectedLogFile: LogFile | null = null;
	let logMessages: LogMessage[] = [];
	let loading = true;
	let logsLoading = false;
	let showAddLogFileModal = false;
	let autoRefresh = true;
	let refreshInterval: NodeJS.Timeout | null = null;

	// 日志查看参数
	let logLimit = 100;
	let logLevelFilter = 'all';
	let searchQuery = '';

	// 添加日志文件表单
	let logFileForm: AddLogFileRequest = {
		alias: '',
		filePath: ''
	};

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
		webSocketService.subscribe('agent_status', handleAgentStatus);
		
		// 开始自动刷新
		if (autoRefresh) {
			startAutoRefresh();
		}
	});

	onDestroy(() => {
		// 清理WebSocket订阅
		webSocketService.unsubscribe('log', handleLogMessage);
		webSocketService.unsubscribe('agent_status', handleAgentStatus);
		
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

	function handleAgentStatus(data: any) {
		if (data.agentId === agentId && agent) {
			agent.isConnected = data.status === 'connected';
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

	async function toggleLogFileMonitoring(logFile: LogFile) {
		try {
			if (logFile.enabled) {
				await stopLogFileMonitoring(agentId, logFile.alias);
			} else {
				await startLogFileMonitoring(agentId, logFile.alias);
			}
			await loadLogFiles();
		} catch (error) {
			console.error('Failed to toggle log file monitoring:', error);
		}
	}

	function openAddLogFileModal() {
		logFileForm = { alias: '', filePath: '' };
		showAddLogFileModal = true;
	}

	function closeAddLogFileModal() {
		showAddLogFileModal = false;
	}

	async function handleAddLogFile() {
		try {
			await addLogFile(agentId, logFileForm);
			await loadLogFiles();
			closeAddLogFileModal();
		} catch (error) {
			console.error('Failed to add log file:', error);
		}
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
	<title>Agent详情 - {agent?.agent.name || 'Loading'}</title>
</svelte:head>

<div class="container">
	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>加载Agent详情中...</p>
		</div>
	{:else if agent}
		<!-- Agent 头部信息 -->
		<div class="agent-header">
			<div class="agent-info">
				<h1>{agent.agent.name}</h1>
				<div class="agent-status">
					<span class="status-dot {agent.isConnected ? 'connected' : 'disconnected'}"></span>
					<span class="status-text {agent.isConnected ? 'status-connected' : 'status-disconnected'}">
						{agent.isConnected ? '已连接' : '未连接'}
					</span>
				</div>
			</div>
			<div class="agent-actions">
				<a href="/agents" class="btn btn-secondary">← 返回列表</a>
				<button class="btn btn-primary" on:click={openAddLogFileModal}>
					➕ 添加日志文件
				</button>
			</div>
		</div>

		<!-- Agent 基本信息 -->
		<div class="info-card">
			<h2>📋 基本信息</h2>
			<div class="info-grid">
				<div class="info-item">
					<span class="info-label">地址:</span>
					<span class="info-value">{agent.agent.host}:{agent.agent.port}</span>
				</div>
				<div class="info-item">
					<span class="info-label">协议:</span>
					<span class="info-value">{agent.agent.useTls ? 'WSS' : 'WS'}</span>
				</div>
				<div class="info-item">
					<span class="info-label">状态:</span>
					<span class="info-value">{agent.agent.enabled ? '启用' : '禁用'}</span>
				</div>
				<div class="info-item">
					<span class="info-label">日志文件:</span>
					<span class="info-value">{logFiles.length} 个</span>
				</div>
				{#if agent.agent.description}
					<div class="info-item full-width">
						<span class="info-label">描述:</span>
						<span class="info-value">{agent.agent.description}</span>
					</div>
				{/if}
				{#if agent.agent.tags.length > 0}
					<div class="info-item full-width">
						<span class="info-label">标签:</span>
						<div class="tags">
							{#each agent.agent.tags as tag}
								<span class="tag">{tag}</span>
							{/each}
						</div>
					</div>
				{/if}
			</div>
		</div>

		<!-- 日志文件列表和查看 -->
		<div class="logs-section">
			<div class="logs-header">
				<h2>📄 日志文件</h2>
				<div class="logs-controls">
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
				</div>
			</div>

			{#if logFiles.length === 0}
				<div class="empty-state">
					<h3>📂 暂无日志文件</h3>
					<p>点击上方按钮添加第一个日志文件</p>
				</div>
			{:else}
				<div class="logs-layout">
					<!-- 日志文件列表 -->
					<div class="log-files-panel">
						<h3>日志文件列表</h3>
						<div class="log-files-list">
							{#each logFiles as logFile}
								<div 
									class="log-file-item {selectedLogFile?.id === logFile.id ? 'selected' : ''}"
									on:click={() => selectLogFile(logFile)}
									role="button"
									tabindex="0"
									on:keydown={(e) => e.key === 'Enter' && selectLogFile(logFile)}
								>
									<div class="log-file-info">
										<div class="log-file-name">{logFile.alias}</div>
										<div class="log-file-path">{logFile.filePath}</div>
									</div>
									<div class="log-file-actions">
										<button
											class="btn btn-small {logFile.enabled ? 'btn-danger' : 'btn-primary'}"
											on:click|stopPropagation={() => toggleLogFileMonitoring(logFile)}
										>
											{logFile.enabled ? '⏹️ 停止' : '▶️ 启动'}
										</button>
									</div>
								</div>
							{/each}
						</div>
					</div>

					<!-- 日志内容查看 -->
					<div class="log-content-panel">
						{#if selectedLogFile}
							<div class="log-content-header">
								<h3>📄 {selectedLogFile.alias}</h3>
								<div class="log-stats">
									<span>共 {filteredLogMessages.length} 条日志</span>
									{#if logsLoading}
										<span class="loading-indicator">🔄 加载中...</span>
									{/if}
								</div>
							</div>

							<div class="log-content">
								{#if filteredLogMessages.length === 0}
									<div class="empty-logs">
										{#if logsLoading}
											<p>正在加载日志...</p>
										{:else}
											<p>暂无日志数据</p>
										{/if}
									</div>
								{:else}
									<div class="log-messages">
										{#each filteredLogMessages as message}
											<div class="log-entry {getLogLevelClass(message.level)}">
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
						{:else}
							<div class="no-selection">
								<h3>请选择一个日志文件</h3>
								<p>从左侧列表中选择要查看的日志文件</p>
							</div>
						{/if}
					</div>
				</div>
			{/if}
		</div>
	{:else}
		<div class="error">
			<h2>❌ Agent不存在</h2>
			<p>请检查Agent ID是否正确</p>
			<a href="/agents" class="btn btn-primary">返回列表</a>
		</div>
	{/if}
</div>

<!-- 添加日志文件Modal -->
{#if showAddLogFileModal}
	<div class="modal" on:click={closeAddLogFileModal} role="dialog" aria-modal="true" tabindex="-1">
		<div class="modal-content" on:click|stopPropagation role="document">
			<h2>添加日志文件</h2>
			
			<form on:submit|preventDefault={handleAddLogFile}>
				<div class="form-group">
					<label for="alias">别名 *</label>
					<input 
						id="alias"
						type="text" 
						class="input" 
						bind:value={logFileForm.alias} 
						required 
						placeholder="如: nginx-access"
					/>
				</div>

				<div class="form-group">
					<label for="filePath">文件路径 *</label>
					<input 
						id="filePath"
						type="text" 
						class="input" 
						bind:value={logFileForm.filePath} 
						required 
						placeholder="如: /var/log/nginx/access.log"
					/>
				</div>

				<div class="form-actions">
					<button type="button" class="btn btn-secondary" on:click={closeAddLogFileModal}>
						取消
					</button>
					<button type="submit" class="btn btn-primary">
						添加
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

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

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.agent-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 2rem;
		padding: 1.5rem;
		background: rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		border: 1px solid rgba(255, 255, 255, 0.2);
		backdrop-filter: blur(10px);
	}

	.agent-info h1 {
		margin: 0 0 0.5rem 0;
		font-size: 2rem;
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

	.agent-actions {
		display: flex;
		gap: 1rem;
	}

	.info-card {
		background: rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		border: 1px solid rgba(255, 255, 255, 0.2);
		backdrop-filter: blur(10px);
		padding: 1.5rem;
		margin-bottom: 2rem;
	}

	.info-card h2 {
		margin: 0 0 1rem 0;
		font-size: 1.2rem;
		color: #667eea;
	}

	.info-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1rem;
	}

	.info-item {
		display: flex;
		justify-content: space-between;
		padding: 0.5rem 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
	}

	.info-item.full-width {
		grid-column: 1 / -1;
		flex-direction: column;
		gap: 0.5rem;
	}

	.info-label {
		color: rgba(255, 255, 255, 0.8);
		font-weight: 500;
	}

	.info-value {
		color: #667eea;
		font-family: var(--font-mono);
		font-size: 0.875rem;
	}

	.tags {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
	}

	.tag {
		background: rgba(102, 126, 234, 0.2);
		color: #667eea;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		font-size: 0.75rem;
	}

	.logs-section {
		background: rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		border: 1px solid rgba(255, 255, 255, 0.2);
		backdrop-filter: blur(10px);
		padding: 1.5rem;
	}

	.logs-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1.5rem;
		flex-wrap: wrap;
		gap: 1rem;
	}

	.logs-header h2 {
		margin: 0;
		font-size: 1.2rem;
		color: #667eea;
	}

	.logs-controls {
		display: flex;
		gap: 1rem;
		align-items: center;
		flex-wrap: wrap;
	}

	.logs-controls label {
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
		min-width: 200px;
	}

	.empty-state, .no-selection {
		text-align: center;
		padding: 3rem;
		color: rgba(255, 255, 255, 0.6);
	}

	.logs-layout {
		display: grid;
		grid-template-columns: 300px 1fr;
		gap: 1.5rem;
		height: 600px;
	}

	.log-files-panel {
		background: rgba(0, 0, 0, 0.2);
		border-radius: 8px;
		padding: 1rem;
		overflow-y: auto;
	}

	.log-files-panel h3 {
		margin: 0 0 1rem 0;
		font-size: 1rem;
		color: rgba(255, 255, 255, 0.9);
	}

	.log-files-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.log-file-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem;
		background: rgba(255, 255, 255, 0.05);
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s;
		border: 1px solid transparent;
	}

	.log-file-item:hover {
		background: rgba(255, 255, 255, 0.1);
	}

	.log-file-item.selected {
		background: rgba(102, 126, 234, 0.2);
		border-color: #667eea;
	}

	.log-file-info {
		flex: 1;
		min-width: 0;
	}

	.log-file-name {
		font-weight: 500;
		margin-bottom: 0.25rem;
	}

	.log-file-path {
		font-size: 0.75rem;
		color: rgba(255, 255, 255, 0.6);
		font-family: var(--font-mono);
		word-break: break-all;
	}

	.log-file-actions {
		margin-left: 0.5rem;
	}

	.btn-small {
		padding: 0.25rem 0.5rem;
		font-size: 0.75rem;
	}

	.log-content-panel {
		background: rgba(0, 0, 0, 0.2);
		border-radius: 8px;
		padding: 1rem;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.log-content-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
		padding-bottom: 0.5rem;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
	}

	.log-content-header h3 {
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
		flex: 1;
		overflow-y: auto;
	}

	.empty-logs {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		color: rgba(255, 255, 255, 0.6);
	}

	.log-messages {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.log-entry {
		display: grid;
		grid-template-columns: auto auto 1fr;
		gap: 0.75rem;
		padding: 0.5rem;
		border-radius: 4px;
		background: rgba(255, 255, 255, 0.05);
		border-left: 3px solid #667eea;
		font-family: var(--font-mono);
		font-size: 0.875rem;
		align-items: start;
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

	.form-group {
		margin-bottom: 1rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 500;
	}

	.form-actions {
		display: flex;
		gap: 1rem;
		justify-content: flex-end;
		margin-top: 2rem;
	}

	@media (max-width: 1024px) {
		.logs-layout {
			grid-template-columns: 1fr;
			height: auto;
		}

		.log-files-panel {
			height: 200px;
		}

		.log-content-panel {
			height: 400px;
		}
	}

	@media (max-width: 768px) {
		.container {
			padding: 1rem;
		}

		.agent-header {
			flex-direction: column;
			gap: 1rem;
			align-items: stretch;
		}

		.agent-actions {
			justify-content: center;
		}

		.logs-header {
			flex-direction: column;
			align-items: stretch;
		}

		.logs-controls {
			flex-direction: column;
			align-items: stretch;
		}

		.logs-controls label {
			justify-content: space-between;
		}

		.info-grid {
			grid-template-columns: 1fr;
		}
	}
</style> 