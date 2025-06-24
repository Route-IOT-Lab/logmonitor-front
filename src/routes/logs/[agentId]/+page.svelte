<script lang="ts">
	import { page } from '$app/stores';
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { 
		getAgent, 
		getLogFiles, 
		getLogFileTail,
		updateLogFile,
		deleteLogFile,
		addLogFile,
		startLogFileMonitoring
	} from '$lib/services/api';
	import { webSocketService } from '$lib/services/websocket';
	import type { AgentDetailView, LogFile, LogMessage, AddLogFileRequest } from '$lib/types';

	let agentId: number;
	let agent: AgentDetailView | null = null;
	let logFiles: LogFile[] = [];
	let selectedLogFile: LogFile | null = null;
	let loading = true;
	let logsLoading = false;

	// WebSocket实时日志
	let realtimeLogs: LogMessage[] = [];
	let isRealtime = false;
	let autoRefreshInterval: NodeJS.Timeout | null = null;
	let wsConnected = false;
	let wsConnecting = false;

	// 日志查看参数
	let logLimit = 100;
	let logLevelFilter = 'all';
	let searchQuery = '';
	let autoScroll = true;

	// 编辑和删除功能状态
	let showEditLogFileModal = false;
	let showDeleteConfirmModal = false;
	let showAddLogFileModal = false;
	let editingLogFile: LogFile | null = null;
	let deletingLogFile: LogFile | null = null;
	let editLogFileForm: AddLogFileRequest = {
		alias: '',
		filePath: ''
	};
	let addLogFileForm: AddLogFileRequest = {
		alias: '',
		filePath: ''
	};

	// 侧边栏状态
	let sidebarCollapsed = false;
	let isMobile = false;

	$: agentId = parseInt($page.params.agentId);

	onMount(async () => {
		// 初始化移动端状态
		isMobile = window.innerWidth <= 768;
		if (isMobile) {
			sidebarCollapsed = true;
		}
		
		// 监听窗口大小变化
		const handleResize = () => {
			const newIsMobile = window.innerWidth <= 768;
			if (newIsMobile !== isMobile) {
				isMobile = newIsMobile;
				if (isMobile) {
					sidebarCollapsed = true; // 切换到移动端时自动折叠
				}
			}
		};
		
		window.addEventListener('resize', handleResize);
		
		// 并行启动WebSocket连接和数据加载
		console.log('🚀 Initializing log workspace...');
		
		const connectWebSocket = async () => {
			console.log('🔗 Connecting to WebSocket...');
			if (!webSocketService.isConnected()) {
				try {
					await webSocketService.connect();
					console.log('✅ WebSocket connected');
				} catch (error) {
					console.error('❌ WebSocket connection failed:', error);
				}
			} else {
				console.log('✅ WebSocket already connected');
			}

			// 订阅实时日志
			webSocketService.subscribe('log', handleRealtimeLog);
			webSocketService.subscribe('AGENT_STATUS', handleAgentStatus);
			console.log('✅ WebSocket subscriptions registered');
		};
		
		// 并行执行WebSocket连接和数据加载
		await Promise.all([
			connectWebSocket(),
			loadAgent(),
			loadLogFiles()
		]);
		
		console.log('✅ Initialization completed');
		
		// 清理函数
		return () => {
			window.removeEventListener('resize', handleResize);
		};
	});

	onDestroy(() => {
		// 清理WebSocket订阅
		webSocketService.unsubscribe('log', handleRealtimeLog);
		webSocketService.unsubscribe('AGENT_STATUS', handleAgentStatus);
		
		// 取消所有监控订阅
		if (selectedLogFile && isRealtime) {
			webSocketService.unsubscribeFromAgent(agentId, selectedLogFile.alias);
		}
		
		// 清理轮询
		stopRealtimePolling();
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
			const logs = await getLogFileTail(agentId, selectedLogFile.alias, logLimit);
			
			// 只有在首次加载时才替换数据，其他情况都保持现有数据
			if (realtimeLogs.length === 0) {
				console.log('📄 Loading logs for:', selectedLogFile.alias);
				realtimeLogs = logs;
			}
		} catch (error) {
			console.error('Failed to load logs:', error);
		} finally {
			logsLoading = false;
		}
	}

	// 手动刷新功能 - 会清空并重新加载
	async function refreshLogs() {
		if (!selectedLogFile) return;
		
		logsLoading = true;
		try {
			console.log('🔄 Refreshing logs for:', selectedLogFile.alias);
			const logs = await getLogFileTail(agentId, selectedLogFile.alias, logLimit);
			realtimeLogs = logs; // 只有手动刷新才清空重新加载
		} catch (error) {
			console.error('Failed to refresh logs:', error);
		} finally {
			logsLoading = false;
		}
	}

	function handleRealtimeLog(data: any) {
		console.log('📨 Received realtime log:', data?.content);
		
		// 根据实际WebSocket消息结构验证数据有效性
		if (!data || data.agentId === undefined || !selectedLogFile) {
			console.warn('⚠️ Invalid log message data');
			return;
		}
		
		if (data.agentId === agentId) {
			const alias = data.logFileAlias;
			
			if (alias === selectedLogFile.alias) {
				// 根据实际消息结构创建日志消息
				const logMessage = {
					id: data.timestamp || Date.now(),
					content: data.content || '',
					timestamp: data.timestamp ? new Date(data.timestamp).toISOString() : new Date().toISOString(),
					level: data.level || 'INFO',
					createdAt: data.timestamp ? new Date(data.timestamp).toISOString() : new Date().toISOString()
				};
				
				// 添加新日志到底部，保持历史数据
				const oldLength = realtimeLogs.length;
				realtimeLogs = [...realtimeLogs.slice(-(logLimit - 1)), logMessage];
				console.log(`✅ Added log message to bottom. Count: ${oldLength} -> ${realtimeLogs.length}`);
				
				// 自动滚动到最新日志（底部）
				if (autoScroll) {
					setTimeout(() => {
						const logContainer = document.querySelector('.log-content');
						if (logContainer) {
							logContainer.scrollTop = logContainer.scrollHeight;
						}
					}, 50);
				}
			}
		}
	}

	function handleAgentStatus(data: any) {
		console.log('Received AGENT_STATUS:', data); // 调试日志
		
		if (data.agentId === agentId && agent) {
			agent.isConnected = data.isConnected;
		}
	}

	function toggleRealtime() {
		isRealtime = !isRealtime;
		
		if (isRealtime && selectedLogFile) {
			// 启用实时模式
			console.log('启用实时模式:', agentId, selectedLogFile.alias);
			
			// 尝试WebSocket订阅（可能不工作）
			webSocketService.subscribeToAgent(agentId, selectedLogFile.alias);
			
			// 启动轮询作为主要的实时更新方式
			startRealtimePolling();
		} else if (selectedLogFile) {
			// 禁用实时模式
			console.log('禁用实时模式:', agentId, selectedLogFile.alias);
			
			// 取消WebSocket订阅
			webSocketService.unsubscribeFromAgent(agentId, selectedLogFile.alias);
			
			// 停止轮询
			stopRealtimePolling();
		}
	}

	function startRealtimePolling() {
		// 停止之前的轮询
		stopRealtimePolling();
		
		// 每2秒轮询一次新日志
		autoRefreshInterval = setInterval(async () => {
			if (selectedLogFile && !logsLoading && isRealtime) {
				console.log('实时轮询日志:', selectedLogFile.alias);
				await pollNewLogs();
			}
		}, 2000);
	}

	function stopRealtimePolling() {
		if (autoRefreshInterval) {
			clearInterval(autoRefreshInterval);
			autoRefreshInterval = null;
		}
	}

	// 轮询新日志（只获取新增的，不清空现有数据）
	async function pollNewLogs() {
		if (!selectedLogFile || !isRealtime) return;
		
		try {
			// 获取最新的少量日志来检查是否有新内容
			const latestLogs = await getLogFileTail(agentId, selectedLogFile.alias, 10);
			
			if (latestLogs.length > 0 && realtimeLogs.length > 0) {
				// 检查是否有新日志（比较最后一条日志）
				const lastKnownContent = realtimeLogs[realtimeLogs.length - 1].content;
				const latestContent = latestLogs[0].content;
				
				if (latestContent !== lastKnownContent) {
					// 有新日志，找出新增的部分
					const newLogs = [];
					for (const log of latestLogs) {
						const exists = realtimeLogs.some(existing => 
							existing.content === log.content && 
							existing.timestamp === log.timestamp
						);
						if (!exists) {
							newLogs.push(log); // 正序添加到底部
						}
					}
					
					if (newLogs.length > 0) {
						console.log(`发现 ${newLogs.length} 条新日志`);
						// 将新日志添加到底部，保持总数限制
						const totalLogs = [...realtimeLogs, ...newLogs];
						realtimeLogs = totalLogs.slice(-logLimit);
						
						// 自动滚动到底部
						if (autoScroll) {
							setTimeout(() => {
								const logContainer = document.querySelector('.log-content');
								if (logContainer) {
									logContainer.scrollTop = logContainer.scrollHeight;
								}
							}, 100);
						}
					}
				}
			}
		} catch (error) {
			console.error('轮询新日志失败:', error);
		}
	}

	async function selectLogFile(logFile: LogFile) {
		// 取消之前的订阅
		if (selectedLogFile && isRealtime) {
			console.log('Unsubscribing from previous log file:', agentId, selectedLogFile.alias);
			webSocketService.unsubscribeFromAgent(agentId, selectedLogFile.alias);
		}
		
		selectedLogFile = logFile;
		await loadLogs();
		
		// 如果是实时模式，订阅新的日志文件
		if (isRealtime) {
			console.log('Subscribing to new log file:', agentId, logFile.alias);
			webSocketService.subscribeToAgent(agentId, logFile.alias);
		}
	}

	// 编辑日志文件功能
	function openEditLogFileModal(logFile: LogFile) {
		editingLogFile = logFile;
		editLogFileForm = {
			alias: logFile.alias,
			filePath: logFile.filePath
		};
		showEditLogFileModal = true;
	}

	function closeEditLogFileModal() {
		showEditLogFileModal = false;
		editingLogFile = null;
		editLogFileForm = { alias: '', filePath: '' };
	}

	async function handleEditLogFile() {
		if (!editingLogFile) return;
		
		// 客户端验证
		if (!editLogFileForm.alias || !editLogFileForm.alias.trim()) {
			alert('请输入日志文件别名');
			return;
		}
		
		if (!editLogFileForm.filePath || !editLogFileForm.filePath.trim()) {
			alert('请输入日志文件路径');
			return;
		}
		
		// 检查新别名是否与其他文件重复（排除当前编辑的文件）
		const trimmedAlias = editLogFileForm.alias.trim();
		const existingFile = logFiles.find(file => 
			file.alias === trimmedAlias && file.id !== editingLogFile.id
		);
		if (existingFile) {
			alert(`别名 "${trimmedAlias}" 已被其他日志文件使用，请使用其他别名`);
			return;
		}
		
		try {
			const trimmedForm = {
				alias: trimmedAlias,
				filePath: editLogFileForm.filePath.trim()
			};
			
			const updatedLogFile = await updateLogFile(agentId, editingLogFile.alias, trimmedForm);
			if (updatedLogFile) {
				await loadLogFiles();
				// 如果编辑的是当前选中的文件，更新选中状态
				if (selectedLogFile?.id === editingLogFile.id) {
					selectedLogFile = updatedLogFile;
					await loadLogs();
				}
				closeEditLogFileModal();
			} else {
				alert('更新日志文件失败，请检查别名是否重复或文件路径是否正确');
			}
		} catch (error) {
			console.error('Failed to edit log file:', error);
			alert('更新日志文件失败: ' + (error.message || '未知错误'));
		}
	}

	// 删除日志文件功能
	function openDeleteConfirmModal(logFile: LogFile) {
		deletingLogFile = logFile;
		showDeleteConfirmModal = true;
	}

	function closeDeleteConfirmModal() {
		showDeleteConfirmModal = false;
		deletingLogFile = null;
	}

	async function handleDeleteLogFile() {
		if (!deletingLogFile) return;
		
		try {
			const success = await deleteLogFile(agentId, deletingLogFile.alias);
			if (success) {
				// 如果删除的是当前选中的文件，清除选中状态
				if (selectedLogFile?.id === deletingLogFile.id) {
					selectedLogFile = null;
					realtimeLogs = [];
				}
				
				await loadLogFiles();
				closeDeleteConfirmModal();
			} else {
				alert('删除日志文件失败');
			}
		} catch (error) {
			console.error('Failed to delete log file:', error);
			alert('删除日志文件失败');
		}
	}

	// 添加日志文件功能
	function openAddLogFileModal() {
		addLogFileForm = { alias: '', filePath: '' };
		showAddLogFileModal = true;
	}

	function closeAddLogFileModal() {
		showAddLogFileModal = false;
		addLogFileForm = { alias: '', filePath: '' };
	}

	async function handleAddLogFile() {
		// 客户端验证
		if (!addLogFileForm.alias || !addLogFileForm.alias.trim()) {
			alert('请输入日志文件别名');
			return;
		}
		
		if (!addLogFileForm.filePath || !addLogFileForm.filePath.trim()) {
			alert('请输入日志文件路径');
			return;
		}
		
		// 检查别名是否已存在
		const existingFile = logFiles.find(file => file.alias === addLogFileForm.alias.trim());
		if (existingFile) {
			alert(`别名 "${addLogFileForm.alias.trim()}" 已存在，请使用其他别名`);
			return;
		}
		
		try {
			const trimmedForm = {
				alias: addLogFileForm.alias.trim(),
				filePath: addLogFileForm.filePath.trim()
			};
			
			const newLogFile = await addLogFile(agentId, trimmedForm);
			if (newLogFile) {
				// 自动启动新添加的日志文件监听
				console.log('Starting monitoring for new log file:', newLogFile.alias);
				const startSuccess = await startLogFileMonitoring(agentId, newLogFile.alias);
				if (startSuccess) {
					console.log('✅ Successfully started monitoring for:', newLogFile.alias);
				} else {
					console.warn('⚠️ Failed to start monitoring for:', newLogFile.alias);
				}
				
				await loadLogFiles();
				closeAddLogFileModal();
			} else {
				alert('添加日志文件失败，请检查别名是否重复或文件路径是否正确');
			}
		} catch (error) {
			console.error('Failed to add log file:', error);
			alert('添加日志文件失败: ' + (error.message || '未知错误'));
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
		try {
			return new Date(timestamp).toLocaleString();
		} catch {
			return timestamp;
		}
	}

	function clearLogs() {
		realtimeLogs = [];
	}

	// 过滤日志消息
	$: filteredLogs = realtimeLogs.filter(message => {
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
	<title>日志工作台 - {agent?.agent.name || 'Loading'}</title>
</svelte:head>

<div class="workspace">
	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>加载Agent信息中...</p>
		</div>
	{:else if agent}
		<!-- 顶部导航栏 -->
		<div class="header">
			<div class="header-left">
				<button class="sidebar-toggle" on:click={() => sidebarCollapsed = !sidebarCollapsed}>
					{sidebarCollapsed ? '📂' : '📁'}
				</button>
				<div class="breadcrumb">
					<a href="/agents">🤖 Agents</a>
					<span>›</span>
					<span>{agent.agent.name}</span>
					<span>›</span>
					<span>📄 日志工作台</span>
				</div>
			</div>
			<div class="header-right">
				<div class="agent-status {agent.isConnected ? 'connected' : 'disconnected'}">
					{agent.isConnected ? '🟢 已连接' : '🔴 未连接'}
				</div>
				<button class="btn btn-primary" on:click={openAddLogFileModal}>
					➕ 添加日志文件
				</button>
			</div>
		</div>

		<div class="main-content">
			<!-- 移动端遮罩层 -->
			{#if isMobile && !sidebarCollapsed}
				<div class="sidebar-overlay" on:click={() => sidebarCollapsed = true}></div>
			{/if}
			
			<!-- 侧边栏 -->
			<div class="sidebar {sidebarCollapsed ? 'collapsed' : ''}">
				<div class="sidebar-header">
					<h3>📄 日志文件</h3>
					<span class="file-count">{logFiles.length}</span>
				</div>
				
				{#if logFiles.length === 0}
					<div class="sidebar-empty">
						<p>暂无日志文件</p>
						<button class="btn btn-small btn-primary" on:click={openAddLogFileModal}>
							➕ 添加
						</button>
					</div>
				{:else}
					<div class="file-list">
						{#each logFiles as logFile}
							<div class="file-item {selectedLogFile?.id === logFile.id ? 'active' : ''}"
								 on:click={() => selectLogFile(logFile)}>
								<div class="file-info">
									<div class="file-name">📄 {logFile.alias}</div>
									<div class="file-path">{logFile.filePath}</div>
									<div class="file-status {logFile.enabled ? 'enabled' : 'disabled'}">
										{logFile.enabled ? '🟢 监控中' : '🔴 已停用'}
									</div>
								</div>
								<div class="file-actions">
									<button class="btn-icon" on:click|stopPropagation={() => openEditLogFileModal(logFile)} title="编辑">
										✏️
									</button>
									<button class="btn-icon" on:click|stopPropagation={() => openDeleteConfirmModal(logFile)} title="删除">
										🗑️
									</button>
								</div>
							</div>
						{/each}
					</div>
				{/if}
			</div>

			<!-- 主要内容区域 -->
			<div class="content-area">
				{#if selectedLogFile}
					<!-- 控制面板 -->
					<div class="control-panel">
						<div class="panel-left">
							<h2>🖥️ {selectedLogFile.alias}</h2>
							<span class="file-path-display">{selectedLogFile.filePath}</span>
						</div>
						<div class="panel-right">
							<div class="control-group">
								<label>
									📊 显示条数:
									<select bind:value={logLimit} on:change={refreshLogs} class="input small">
										<option value={50}>50行</option>
										<option value={100}>100行</option>
										<option value={200}>200行</option>
										<option value={500}>500行</option>
										<option value={1000}>1000行</option>
									</select>
								</label>
							</div>
							
							<div class="control-group">
								<label>
									🏷️ 级别:
									<select bind:value={logLevelFilter} class="input small">
										<option value="all">全部</option>
										<option value="error">错误</option>
										<option value="warn">警告</option>
										<option value="info">信息</option>
										<option value="debug">调试</option>
									</select>
								</label>
							</div>

							<div class="control-group">
								<input 
									type="text" 
									bind:value={searchQuery} 
									placeholder="🔍 搜索日志..."
									class="input small search-input"
								/>
							</div>

							<div class="control-group">
								<label class="toggle-label">
									<input type="checkbox" bind:checked={isRealtime} on:change={toggleRealtime} />
									<span>{isRealtime ? '🔴 实时' : '⏸️ 历史'}</span>
								</label>
							</div>

							<div class="control-group">
								<label class="toggle-label">
									<input type="checkbox" bind:checked={autoScroll} />
									<span>📜 自动滚动</span>
								</label>
							</div>

							<button class="btn btn-secondary" on:click={refreshLogs}>
								🔄 刷新
							</button>
							
							<button class="btn btn-warning" on:click={clearLogs}>
								🧹 清空
							</button>
							
							<div class="ws-status {webSocketService.isConnected() ? 'connected' : 'disconnected'}">
								{webSocketService.isConnected() ? '🟢 WS已连接' : '🔴 WS未连接'}
							</div>
						</div>
					</div>

					<!-- 日志显示区域 -->
					<div class="log-viewer">
						<div class="log-viewer-header">
							<div class="log-stats">
								<span>显示 {filteredLogs.length} / {realtimeLogs.length} 条日志</span>
								{#if logsLoading}
									<span class="loading-indicator">🔄 加载中...</span>
								{/if}
							</div>
						</div>
						
						<div class="log-content">
							{#if filteredLogs.length === 0}
								<div class="empty-logs">
									{#if logsLoading}
										<div class="loading-text">⏳ 加载日志中...</div>
									{:else}
										<div class="empty-text">📭 暂无日志数据</div>
										<div class="empty-hint">
											{#if !selectedLogFile.enabled}
												💡 日志文件未启用监控
											{:else if searchQuery || logLevelFilter !== 'all'}
												💡 尝试调整过滤条件
											{:else}
												💡 点击"刷新"按钮加载日志
											{/if}
										</div>
									{/if}
								</div>
							{:else}
								<div class="log-messages">
									{#each filteredLogs as message, index}
										<div class="log-line {getLogLevelClass(message.level)}">
											<div class="log-header">
												<span class="log-index">{index + 1}</span>
												<span class="log-timestamp">
													{formatTimestamp(message.timestamp || message.createdAt)}
												</span>
												<span class="log-level">[{message.level.toUpperCase()}]</span>
											</div>
											<div class="log-content-text">{message.content}</div>
										</div>
									{/each}
								</div>
							{/if}
						</div>
					</div>
				{:else}
					<div class="no-selection">
						<div class="empty-icon">📂</div>
						<h3>请选择日志文件</h3>
						<p>从左侧选择要查看的日志文件</p>
					</div>
				{/if}
			</div>
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
			<h2>➕ 添加日志文件</h2>
			
			<form on:submit|preventDefault={handleAddLogFile}>
				<div class="form-group">
					<label for="add-alias">📝 别名 *</label>
					<input 
						id="add-alias"
						type="text" 
						class="input" 
						bind:value={addLogFileForm.alias} 
						required 
						placeholder="如: nginx-access"
					/>
				</div>

				<div class="form-group">
					<label for="add-filePath">📁 文件路径 *</label>
					<input 
						id="add-filePath"
						type="text" 
						class="input" 
						bind:value={addLogFileForm.filePath} 
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

<!-- 编辑日志文件Modal -->
{#if showEditLogFileModal && editingLogFile}
	<div class="modal" on:click={closeEditLogFileModal} role="dialog" aria-modal="true" tabindex="-1">
		<div class="modal-content" on:click|stopPropagation role="document">
			<h2>✏️ 编辑日志文件</h2>
			
			<form on:submit|preventDefault={handleEditLogFile}>
				<div class="form-group">
					<label for="edit-alias">📝 别名 *</label>
					<input 
						id="edit-alias"
						type="text" 
						class="input" 
						bind:value={editLogFileForm.alias} 
						required 
						placeholder="如: nginx-access"
					/>
				</div>

				<div class="form-group">
					<label for="edit-filePath">📁 文件路径 *</label>
					<input 
						id="edit-filePath"
						type="text" 
						class="input" 
						bind:value={editLogFileForm.filePath} 
						required 
						placeholder="如: /var/log/nginx/access.log"
					/>
				</div>

				<div class="form-actions">
					<button type="button" class="btn btn-secondary" on:click={closeEditLogFileModal}>
						取消
					</button>
					<button type="submit" class="btn btn-primary">
						保存
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

<!-- 删除确认Modal -->
{#if showDeleteConfirmModal && deletingLogFile}
	<div class="modal" on:click={closeDeleteConfirmModal} role="dialog" aria-modal="true" tabindex="-1">
		<div class="modal-content" on:click|stopPropagation role="document">
			<h2>🗑️ 确认删除</h2>
			
			<div class="delete-confirm-content">
				<p>您确定要删除以下日志文件吗？</p>
				<div class="file-info">
					<div class="file-detail">
						<strong>📝 别名:</strong> {deletingLogFile.alias}
					</div>
					<div class="file-detail">
						<strong>📁 路径:</strong> {deletingLogFile.filePath}
					</div>
				</div>
				<p class="warning">⚠️ 此操作不可撤销，删除后将无法恢复该日志文件的配置。</p>
			</div>

			<div class="form-actions">
				<button type="button" class="btn btn-secondary" on:click={closeDeleteConfirmModal}>
					取消
				</button>
				<button type="button" class="btn btn-danger" on:click={handleDeleteLogFile}>
					确认删除
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.workspace {
		min-height: 100vh;
		background: #0d1117;
		color: #e6edf3;
		font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 50vh;
		gap: 1rem;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 3px solid rgba(230, 237, 243, 0.3);
		border-left: 3px solid #58a6ff;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	/* 顶部导航栏 */
	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem 1.5rem;
		background: rgba(13, 17, 23, 0.95);
		border-bottom: 1px solid #21262d;
		backdrop-filter: blur(10px);
		position: sticky;
		top: 0;
		z-index: 100;
	}

	.header-left {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.sidebar-toggle {
		background: none;
		border: none;
		font-size: 1.2rem;
		cursor: pointer;
		padding: 0.5rem;
		border-radius: 4px;
		transition: background 0.2s;
	}

	.sidebar-toggle:hover {
		background: rgba(255, 255, 255, 0.1);
	}

	.breadcrumb {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		color: #7d8590;
	}

	.breadcrumb a {
		color: #58a6ff;
		text-decoration: none;
	}

	.breadcrumb a:hover {
		text-decoration: underline;
	}

	.header-right {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.agent-status {
		padding: 0.5rem 1rem;
		border-radius: 20px;
		font-size: 0.875rem;
		font-weight: 500;
	}

	.agent-status.connected {
		background: rgba(46, 160, 67, 0.2);
		color: #3fb950;
		border: 1px solid rgba(46, 160, 67, 0.4);
	}

	.agent-status.disconnected {
		background: rgba(248, 81, 73, 0.2);
		color: #f85149;
		border: 1px solid rgba(248, 81, 73, 0.4);
	}

	/* 主要内容区域 */
	.main-content {
		display: flex;
		height: calc(100vh - 70px);
	}

	/* 侧边栏 */
	.sidebar {
		width: 300px;
		background: rgba(22, 27, 34, 0.8);
		border-right: 1px solid #21262d;
		display: flex;
		flex-direction: column;
		transition: width 0.3s ease;
	}

	.sidebar.collapsed {
		width: 60px;
	}

	.sidebar-header {
		padding: 1rem;
		border-bottom: 1px solid #21262d;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.sidebar.collapsed .sidebar-header h3 {
		display: none;
	}

	.file-count {
		background: #58a6ff;
		color: white;
		padding: 0.25rem 0.5rem;
		border-radius: 10px;
		font-size: 0.75rem;
		font-weight: 500;
	}

	.sidebar-empty {
		padding: 2rem 1rem;
		text-align: center;
		color: #7d8590;
	}

	.file-list {
		flex: 1;
		overflow-y: auto;
		padding: 0.5rem;
	}

	.file-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem;
		margin-bottom: 0.5rem;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
		border: 1px solid transparent;
	}

	.file-item:hover {
		background: rgba(255, 255, 255, 0.05);
		border-color: #30363d;
	}

	.file-item.active {
		background: rgba(88, 166, 255, 0.15);
		border-color: #58a6ff;
	}

	.sidebar.collapsed .file-item {
		flex-direction: column;
		padding: 0.5rem;
	}

	.file-info {
		flex: 1;
		min-width: 0;
	}

	.file-name {
		font-weight: 500;
		font-size: 0.875rem;
		margin-bottom: 0.25rem;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.file-path {
		font-size: 0.75rem;
		color: #7d8590;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		margin-bottom: 0.25rem;
	}

	.file-status {
		font-size: 0.75rem;
		font-weight: 500;
	}

	.file-status.enabled {
		color: #3fb950;
	}

	.file-status.disabled {
		color: #f85149;
	}

	.file-actions {
		display: flex;
		gap: 0.25rem;
		opacity: 0;
		transition: opacity 0.2s;
	}

	.file-item:hover .file-actions {
		opacity: 1;
	}

	.sidebar.collapsed .file-info .file-path,
	.sidebar.collapsed .file-info .file-status {
		display: none;
	}

	.btn-icon {
		background: none;
		border: none;
		font-size: 0.875rem;
		cursor: pointer;
		padding: 0.25rem;
		border-radius: 4px;
		transition: background 0.2s;
	}

	.btn-icon:hover {
		background: rgba(255, 255, 255, 0.1);
	}

	/* 内容区域 */
	.content-area {
		flex: 1;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.control-panel {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem 1.5rem;
		background: rgba(22, 27, 34, 0.8);
		border-bottom: 1px solid #21262d;
		flex-wrap: wrap;
		gap: 1rem;
	}

	.panel-left h2 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
	}

	.file-path-display {
		font-size: 0.75rem;
		color: #7d8590;
		font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
	}

	.panel-right {
		display: flex;
		align-items: center;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.control-group {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.control-group label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		white-space: nowrap;
	}

	.toggle-label {
		cursor: pointer;
		user-select: none;
	}

	.input.small {
		padding: 0.375rem 0.75rem;
		font-size: 0.875rem;
		background: rgba(13, 17, 23, 0.8);
		border: 1px solid #30363d;
		border-radius: 6px;
		color: #e6edf3;
		min-width: 80px;
	}

	.search-input {
		min-width: 150px;
	}

	.input:focus {
		outline: none;
		border-color: #58a6ff;
		box-shadow: 0 0 0 3px rgba(88, 166, 255, 0.3);
	}

	/* 日志查看器 */
	.log-viewer {
		flex: 1;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		background: #0d1117;
	}

	.log-viewer-header {
		padding: 0.75rem 1.5rem;
		background: rgba(22, 27, 34, 0.8);
		border-bottom: 1px solid #21262d;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.log-stats {
		display: flex;
		gap: 1rem;
		font-size: 0.875rem;
		color: #7d8590;
	}

	.loading-indicator {
		color: #58a6ff;
		animation: spin 1s linear infinite;
	}

	.log-content {
		flex: 1;
		overflow-y: auto;
		padding: 1rem;
		background: #0d1117;
		scrollbar-width: thin;
		scrollbar-color: #30363d #0d1117;
	}

	.log-content::-webkit-scrollbar {
		width: 8px;
	}

	.log-content::-webkit-scrollbar-track {
		background: #0d1117;
	}

	.log-content::-webkit-scrollbar-thumb {
		background: #30363d;
		border-radius: 4px;
	}

	.log-content::-webkit-scrollbar-thumb:hover {
		background: #484f58;
	}

	.empty-logs {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		text-align: center;
		gap: 0.5rem;
	}

	.loading-text, .empty-text {
		color: #7d8590;
		font-size: 0.875rem;
	}

	.empty-hint {
		color: #656d76;
		font-size: 0.75rem;
	}

	.log-messages {
		font-size: 0.875rem;
		line-height: 1.4;
	}

	.log-line {
		display: flex;
		gap: 0.75rem;
		padding: 0.25rem 0;
		border-left: 2px solid transparent;
		padding-left: 0.5rem;
		margin-left: -0.5rem;
		word-break: break-word;
		align-items: baseline;
	}

	.log-line:hover {
		background: rgba(22, 27, 34, 0.5);
	}

	.log-line.error {
		border-left-color: #f85149;
		background: rgba(248, 81, 73, 0.05);
	}

	.log-line.warn {
		border-left-color: #d29922;
		background: rgba(210, 153, 34, 0.05);
	}

	.log-line.info {
		border-left-color: #58a6ff;
		background: rgba(88, 166, 255, 0.05);
	}

	.log-line.debug {
		border-left-color: #bc8cff;
		background: rgba(188, 140, 255, 0.05);
	}

	.log-index {
		color: #7d8590;
		font-size: 0.75rem;
		width: 3rem;
		text-align: right;
		user-select: none;
		flex-shrink: 0;
	}

	.log-timestamp {
		color: #7d8590;
		font-size: 0.75rem;
		white-space: nowrap;
		flex-shrink: 0;
		min-width: 140px;
	}

	.log-level {
		color: #e6edf3;
		font-weight: 600;
		font-size: 0.75rem;
		white-space: nowrap;
		flex-shrink: 0;
		min-width: 60px;
	}

	.log-content-text {
		flex: 1;
		color: #e6edf3;
		word-break: break-word;
	}

	/* 无选择状态 */
	.no-selection {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-align: center;
		gap: 1rem;
		color: #7d8590;
	}

	.empty-icon {
		font-size: 4rem;
		opacity: 0.7;
	}

	/* 按钮样式 */
	.btn {
		padding: 0.5rem 1rem;
		border-radius: 6px;
		border: 1px solid transparent;
		cursor: pointer;
		font-weight: 500;
		font-size: 0.875rem;
		transition: all 0.2s;
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		text-decoration: none;
	}

	.btn-primary {
		background: #238636;
		color: white;
		border-color: rgba(240, 246, 252, 0.1);
	}

	.btn-primary:hover {
		background: #2ea043;
	}

	.btn-secondary {
		background: #21262d;
		color: #e6edf3;
		border-color: #30363d;
	}

	.btn-secondary:hover {
		background: #30363d;
	}

	.btn-danger {
		background: #da3633;
		color: white;
		border-color: rgba(240, 246, 252, 0.1);
	}

	.btn-danger:hover {
		background: #c93c37;
	}

	.btn-warning {
		background: #9e6a03;
		color: white;
		border-color: rgba(240, 246, 252, 0.1);
	}

	.btn-warning:hover {
		background: #d29922;
	}

	.btn-small {
		padding: 0.375rem 0.75rem;
		font-size: 0.75rem;
	}

	/* 模态框样式 */
	.modal {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(1, 4, 9, 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		backdrop-filter: blur(4px);
	}

	.modal-content {
		background: #161b22;
		border-radius: 12px;
		border: 1px solid #30363d;
		padding: 2rem;
		max-width: 500px;
		width: 90vw;
		max-height: 90vh;
		overflow-y: auto;
	}

	.modal-content h2 {
		margin: 0 0 1.5rem 0;
		color: #e6edf3;
		font-size: 1.25rem;
	}

	.form-group {
		margin-bottom: 1rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 500;
		color: #e6edf3;
		font-size: 0.875rem;
	}

	.input {
		width: 100%;
		padding: 0.75rem;
		background: #0d1117;
		border: 1px solid #30363d;
		border-radius: 6px;
		color: #e6edf3;
		font-size: 0.875rem;
	}

	.input::placeholder {
		color: #656d76;
	}

	.form-actions {
		display: flex;
		gap: 1rem;
		justify-content: flex-end;
		margin-top: 1.5rem;
	}

	.delete-confirm-content {
		color: #e6edf3;
	}

	.file-info {
		background: rgba(13, 17, 23, 0.6);
		border-radius: 6px;
		padding: 1rem;
		margin: 1rem 0;
		border: 1px solid #21262d;
	}

	.file-detail {
		margin-bottom: 0.5rem;
		font-size: 0.875rem;
	}

	.file-detail:last-child {
		margin-bottom: 0;
	}

	.warning {
		color: #d29922;
		font-size: 0.875rem;
		margin: 1rem 0 0 0;
		padding: 0.75rem;
		background: rgba(210, 153, 34, 0.1);
		border-radius: 6px;
		border-left: 3px solid #d29922;
	}

	.error {
		text-align: center;
		padding: 3rem;
	}

	.error h2 {
		color: #f85149;
		margin-bottom: 1rem;
	}

	/* 响应式设计 */
	@media (max-width: 768px) {
		.main-content {
			flex-direction: column;
		}

		.sidebar {
			width: 100%;
			height: auto;
			max-height: 200px;
		}

		.sidebar.collapsed {
			width: 100%;
			height: 60px;
		}

		.control-panel {
			flex-direction: column;
			align-items: stretch;
			gap: 1rem;
		}

		.panel-right {
			flex-direction: column;
			align-items: stretch;
		}

		.control-group {
			justify-content: space-between;
		}

		.log-line {
			flex-direction: column;
			gap: 0.25rem;
			align-items: flex-start;
		}

		.log-timestamp, .log-level {
			min-width: auto;
		}
	}

	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal {
		background: #161b22;
		border: 1px solid #30363d;
		border-radius: 12px;
		padding: 1.5rem;
		width: 90%;
		max-width: 500px;
		max-height: 90vh;
		overflow-y: auto;
	}

	.modal h3 {
		margin: 0 0 1rem 0;
		color: #e6edf3;
	}

	.form-group {
		margin-bottom: 1rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		color: #e6edf3;
		font-weight: 500;
	}

	.input {
		width: 100%;
		padding: 0.75rem;
		background: rgba(13, 17, 23, 0.8);
		border: 1px solid #30363d;
		border-radius: 6px;
		color: #e6edf3;
		font-size: 0.875rem;
		box-sizing: border-box;
	}

	.form-actions {
		display: flex;
		gap: 0.75rem;
		justify-content: flex-end;
		margin-top: 1.5rem;
	}

	.delete-confirm {
		text-align: center;
	}

	.delete-confirm .warning-icon {
		font-size: 3rem;
		color: #f85149;
		margin-bottom: 1rem;
	}

	.delete-confirm p {
		margin: 0.5rem 0;
		color: #e6edf3;
	}

	.delete-confirm .file-name {
		font-weight: 600;
		color: #58a6ff;
	}

	/* 响应式设计 - 移动端和小屏幕优化 */
	@media (max-width: 1024px) {
		/* 平板适配 */
		.header {
			padding: 0.75rem 1rem;
		}

		.control-panel {
			padding: 0.75rem 1rem;
			flex-direction: column;
			align-items: stretch;
			gap: 0.75rem;
		}

		.panel-right {
			justify-content: space-between;
			flex-wrap: wrap;
		}

		.sidebar {
			width: 250px;
		}

		.log-content {
			padding: 0.75rem;
		}
	}

	@media (max-width: 768px) {
		/* 移动端适配 */
		.workspace {
			font-size: 14px;
		}

		.header {
			padding: 0.5rem 0.75rem;
			flex-wrap: wrap;
			gap: 0.5rem;
		}

		.header-left {
			flex: 1;
			min-width: 0;
		}

		.breadcrumb {
			font-size: 0.75rem;
			overflow: hidden;
		}

		.breadcrumb span:not(:last-child) {
			white-space: nowrap;
			overflow: hidden;
			text-overflow: ellipsis;
		}

		.header-right {
			flex-wrap: wrap;
			gap: 0.5rem;
		}

		.agent-status {
			padding: 0.375rem 0.75rem;
			font-size: 0.75rem;
		}

		.btn {
			padding: 0.375rem 0.75rem;
			font-size: 0.75rem;
		}

		/* 移动端侧边栏自动折叠 */
		.main-content {
			position: relative;
		}

		.sidebar-overlay {
			position: fixed;
			top: 0;
			left: 0;
			right: 0;
			bottom: 0;
			background: rgba(0, 0, 0, 0.5);
			z-index: 40;
		}

		.sidebar {
			position: absolute;
			left: 0;
			top: 0;
			height: 100%;
			z-index: 50;
			width: 280px;
			transform: translateX(-100%);
			transition: transform 0.3s ease;
			background: rgba(22, 27, 34, 0.95);
			backdrop-filter: blur(10px);
		}

		.sidebar:not(.collapsed) {
			transform: translateX(0);
		}

		.content-area {
			width: 100%;
		}

		.control-panel {
			padding: 0.5rem 0.75rem;
			flex-direction: column;
			gap: 0.5rem;
		}

		.panel-left h2 {
			font-size: 1rem;
		}

		.file-path-display {
			font-size: 0.625rem;
			word-break: break-all;
		}

		.panel-right {
			flex-direction: column;
			align-items: stretch;
			gap: 0.5rem;
		}

		.control-group {
			justify-content: space-between;
		}

		.control-group label {
			font-size: 0.75rem;
		}

		.input.small {
			padding: 0.25rem 0.5rem;
			font-size: 0.75rem;
			min-width: 60px;
		}

		.search-input {
			min-width: 120px;
		}

		.log-viewer-header {
			padding: 0.5rem 0.75rem;
		}

		.log-stats {
			font-size: 0.75rem;
			flex-wrap: wrap;
		}

		.log-content {
			padding: 0.5rem 0.75rem;
		}

		.log-line {
			flex-direction: column;
			gap: 0.25rem;
			padding: 0.5rem 0;
			align-items: flex-start;
		}

		.log-header {
			display: flex;
			gap: 0.5rem;
			font-size: 0.625rem;
			color: #7d8590;
			width: 100%;
		}

		.log-index, .log-timestamp, .log-level {
			font-size: 0.625rem;
			min-width: auto;
		}

		.log-timestamp {
			min-width: 100px;
		}

		.log-level {
			min-width: 40px;
		}

		.log-content-text {
			font-size: 0.75rem;
			margin-top: 0.25rem;
		}

		/* 移动端模态框优化 */
		.modal {
			width: 95%;
			max-width: none;
			margin: 1rem;
			padding: 1rem;
		}

		.form-actions {
			flex-direction: column;
		}

		.btn {
			width: 100%;
			justify-content: center;
		}
	}

	@media (max-width: 480px) {
		/* 小屏手机适配 */
		.workspace {
			font-size: 13px;
		}

		.header {
			padding: 0.375rem 0.5rem;
		}

		.breadcrumb {
			display: none; /* 小屏隐藏面包屑 */
		}

		.sidebar {
			width: 100vw;
		}

		.control-panel {
			padding: 0.375rem 0.5rem;
		}

		.panel-left h2 {
			font-size: 0.875rem;
		}

		.panel-right {
			gap: 0.375rem;
		}

		.control-group {
			flex-direction: column;
			align-items: stretch;
			gap: 0.25rem;
		}

		.control-group label {
			justify-content: space-between;
		}

		.log-content {
			padding: 0.375rem 0.5rem;
		}

		.log-line {
			padding: 0.375rem 0;
		}

		.file-item {
			padding: 0.5rem;
		}

		.file-name {
			font-size: 0.75rem;
		}

		.file-path {
			font-size: 0.625rem;
		}
	}

	/* 横屏适配 */
	@media (max-width: 768px) and (orientation: landscape) {
		.main-content {
			height: calc(100vh - 50px);
		}

		.header {
			padding: 0.25rem 0.5rem;
		}

		.control-panel {
			padding: 0.25rem 0.5rem;
		}

		.log-content {
			padding: 0.25rem 0.5rem;
		}
	}

	/* 高DPI屏幕优化 */
	@media (-webkit-min-device-pixel-ratio: 2), (min-resolution: 2dppx) {
		.log-content {
			-webkit-font-smoothing: antialiased;
			-moz-osx-font-smoothing: grayscale;
		}
	}

	.btn.btn-warning {
		background: #d29922;
		border-color: #d29922;
	}

	.btn.btn-warning:hover {
		background: #b8860b;
		border-color: #b8860b;
	}

	.btn.btn-info {
		background: #58a6ff;
		border-color: #58a6ff;
	}

	.btn.btn-info:hover {
		background: #4493e0;
		border-color: #4493e0;
	}

	.btn-success {
		background: #238636;
		color: white;
		border: 1px solid #238636;
	}

	.btn-success:hover {
		background: #2ea043;
		border-color: #2ea043;
	}

	.ws-status {
		padding: 0.5rem 1rem;
		border-radius: 20px;
		font-size: 0.75rem;
		font-weight: 500;
		white-space: nowrap;
	}

	.ws-status.connected {
		background: rgba(46, 160, 67, 0.2);
		color: #3fb950;
		border: 1px solid rgba(46, 160, 67, 0.4);
	}

	.ws-status.disconnected {
		background: rgba(248, 81, 73, 0.2);
		color: #f85149;
		border: 1px solid rgba(248, 81, 73, 0.4);
	}
</style> 