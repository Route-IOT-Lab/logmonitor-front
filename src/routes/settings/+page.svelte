<script lang="ts">
	import { onMount } from 'svelte';

	let settings = {
		apiBaseUrl: 'http://localhost:8081/api',
		wsUrl: 'ws://localhost:8081/ws',
		refreshInterval: 30000,
		maxLogEntries: 1000,
		autoReconnect: true,
		showTimestamps: true,
		logLevel: 'info'
	};

	let saved = false;

	onMount(() => {
		loadSettings();
	});

	function loadSettings() {
		const stored = localStorage.getItem('log-monitor-settings');
		if (stored) {
			try {
				settings = { ...settings, ...JSON.parse(stored) };
			} catch (error) {
				console.error('Failed to load settings:', error);
			}
		}
	}

	function saveSettings() {
		try {
			localStorage.setItem('log-monitor-settings', JSON.stringify(settings));
			saved = true;
			setTimeout(() => {
				saved = false;
			}, 2000);
		} catch (error) {
			console.error('Failed to save settings:', error);
		}
	}

	function resetSettings() {
		if (confirm('确定要重置所有设置到默认值吗？')) {
			settings = {
				apiBaseUrl: 'http://localhost:8081/api',
				wsUrl: 'ws://localhost:8081/ws',
				refreshInterval: 30000,
				maxLogEntries: 1000,
				autoReconnect: true,
				showTimestamps: true,
				logLevel: 'info'
			};
			saveSettings();
		}
	}
</script>

<svelte:head>
	<title>系统设置 - 日志监控系统</title>
</svelte:head>

<div class="container">
	<header>
		<h1>⚙️ 系统设置</h1>
		<p>配置系统参数和显示选项</p>
	</header>

	<div class="settings-grid">
		<!-- 连接设置 -->
		<div class="settings-panel">
			<h2>🔗 连接设置</h2>
			
			<div class="form-group">
				<label for="apiBaseUrl">API 基础地址</label>
				<input 
					id="apiBaseUrl"
					type="url" 
					class="input" 
					bind:value={settings.apiBaseUrl}
					placeholder="http://localhost:8081/api"
				/>
				<small>后端 API 服务的基础地址</small>
			</div>

			<div class="form-group">
				<label for="wsUrl">WebSocket 地址</label>
				<input 
					id="wsUrl"
					type="url" 
					class="input" 
					bind:value={settings.wsUrl}
					placeholder="ws://localhost:8081/ws"
				/>
				<small>实时日志推送的 WebSocket 地址</small>
			</div>

			<div class="form-group">
				<label class="checkbox-label">
					<input type="checkbox" bind:checked={settings.autoReconnect} />
					自动重连
				</label>
				<small>连接断开时自动尝试重新连接</small>
			</div>
		</div>

		<!-- 显示设置 -->
		<div class="settings-panel">
			<h2>🎨 显示设置</h2>

			<div class="form-group">
				<label for="refreshInterval">刷新间隔 (毫秒)</label>
				<input 
					id="refreshInterval"
					type="number" 
					class="input" 
					bind:value={settings.refreshInterval}
					min="5000"
					max="300000"
					step="5000"
				/>
				<small>数据自动刷新的时间间隔</small>
			</div>

			<div class="form-group">
				<label for="maxLogEntries">最大日志条数</label>
				<input 
					id="maxLogEntries"
					type="number" 
					class="input" 
					bind:value={settings.maxLogEntries}
					min="100"
					max="10000"
					step="100"
				/>
				<small>单个日志文件显示的最大条数</small>
			</div>

			<div class="form-group">
				<label class="checkbox-label">
					<input type="checkbox" bind:checked={settings.showTimestamps} />
					显示时间戳
				</label>
				<small>在日志条目中显示详细时间戳</small>
			</div>

			<div class="form-group">
				<label for="logLevel">默认日志级别</label>
				<select id="logLevel" class="input" bind:value={settings.logLevel}>
					<option value="debug">Debug</option>
					<option value="info">Info</option>
					<option value="warn">Warning</option>
					<option value="error">Error</option>
				</select>
				<small>日志过滤的默认级别</small>
			</div>
		</div>

		<!-- 系统信息 -->
		<div class="settings-panel">
			<h2>📊 系统信息</h2>

			<div class="info-grid">
				<div class="info-item">
					<span class="info-label">前端版本:</span>
					<span class="info-value">1.0.0</span>
				</div>
				<div class="info-item">
					<span class="info-label">构建时间:</span>
					<span class="info-value">{new Date().toLocaleDateString()}</span>
				</div>
				<div class="info-item">
					<span class="info-label">浏览器:</span>
					<span class="info-value">{navigator.userAgent.split(' ')[0]}</span>
				</div>
				<div class="info-item">
					<span class="info-label">本地存储:</span>
					<span class="info-value">{localStorage.length} 项</span>
				</div>
			</div>

			<div class="system-actions">
				<button class="btn btn-secondary" on:click={() => localStorage.clear()}>
					🗑️ 清除缓存
				</button>
				<button class="btn btn-secondary" on:click={() => location.reload()}>
					🔄 重新加载
				</button>
			</div>
		</div>

		<!-- 高级设置 -->
		<div class="settings-panel">
			<h2>🔧 高级设置</h2>

			<div class="form-group">
				<label>数据导出</label>
				<div class="button-group">
					<button class="btn btn-secondary" on:click={() => console.log('Export settings:', settings)}>
						📤 导出设置
					</button>
					<button class="btn btn-secondary" on:click={() => console.log('Export logs')}>
						📤 导出日志
					</button>
				</div>
				<small>将设置和日志数据导出为 JSON 文件</small>
			</div>

			<div class="form-group">
				<label>开发者选项</label>
				<div class="button-group">
					<button class="btn btn-secondary" on:click={() => console.table(settings)}>
						🔍 查看设置
					</button>
					<button class="btn btn-secondary" on:click={() => console.clear()}>
						🧹 清除控制台
					</button>
				</div>
				<small>开发和调试相关的工具</small>
			</div>
		</div>
	</div>

	<!-- 操作按钮 -->
	<div class="actions">
		<button class="btn btn-danger" on:click={resetSettings}>
			🔄 重置设置
		</button>
		<button class="btn btn-primary" on:click={saveSettings}>
			💾 保存设置
		</button>
	</div>

	{#if saved}
		<div class="success-message">
			✅ 设置已保存
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

	.settings-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 1.5rem;
		margin-bottom: 2rem;
	}

	.settings-panel {
		background: rgba(255, 255, 255, 0.1);
		border-radius: 12px;
		border: 1px solid rgba(255, 255, 255, 0.2);
		backdrop-filter: blur(10px);
		padding: 1.5rem;
	}

	.settings-panel h2 {
		margin: 0 0 1.5rem 0;
		font-size: 1.2rem;
		color: #667eea;
	}

	.form-group {
		margin-bottom: 1.5rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 500;
	}

	.form-group small {
		display: block;
		margin-top: 0.25rem;
		font-size: 0.875rem;
		color: rgba(255, 255, 255, 0.6);
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
	}

	.info-grid {
		display: grid;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}

	.info-item {
		display: flex;
		justify-content: space-between;
		padding: 0.5rem 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
	}

	.info-item:last-child {
		border-bottom: none;
	}

	.info-label {
		color: rgba(255, 255, 255, 0.8);
	}

	.info-value {
		font-weight: 500;
		color: #667eea;
		font-family: var(--font-mono);
		font-size: 0.875rem;
	}

	.system-actions {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.system-actions .btn {
		flex: 1;
		min-width: 120px;
	}

	.button-group {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 0.5rem;
	}

	.button-group .btn {
		flex: 1;
	}

	.actions {
		display: flex;
		gap: 1rem;
		justify-content: center;
		margin-top: 2rem;
	}

	.success-message {
		position: fixed;
		top: 2rem;
		right: 2rem;
		background: rgba(74, 222, 128, 0.2);
		color: #4ade80;
		padding: 1rem 1.5rem;
		border-radius: 8px;
		border: 1px solid rgba(74, 222, 128, 0.3);
		backdrop-filter: blur(10px);
		animation: slideIn 0.3s ease-out;
	}

	@keyframes slideIn {
		from {
			transform: translateX(100%);
			opacity: 0;
		}
		to {
			transform: translateX(0);
			opacity: 1;
		}
	}

	@media (max-width: 768px) {
		.container {
			padding: 1rem;
		}

		.settings-grid {
			grid-template-columns: 1fr;
		}

		.actions {
			flex-direction: column;
		}

		.system-actions {
			flex-direction: column;
		}

		.system-actions .btn {
			flex: none;
		}

		.button-group {
			flex-direction: column;
		}

		.button-group .btn {
			flex: none;
		}

		.success-message {
			position: static;
			margin-top: 1rem;
		}
	}
</style>
