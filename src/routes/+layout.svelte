<script>
	import '../app.css';
	import { page } from '$app/stores';
	import { onMount } from 'svelte';

	let showMobileMenu = false;

	// 导航菜单项
	const navItems = [
		{ href: '/', label: '首页', icon: '🏠' },
		{ href: '/agents', label: 'Agents', icon: '🤖' },
		{ href: '/logs', label: '日志', icon: '📄' },
		{ href: '/monitoring', label: '监控', icon: '📊' },
		{ href: '/settings', label: '设置', icon: '⚙️' }
	];

	function toggleMobileMenu() {
		showMobileMenu = !showMobileMenu;
	}

	function closeMobileMenu() {
		showMobileMenu = false;
	}

	// 监听路由变化，关闭移动端菜单
	$: if ($page.url.pathname) {
		showMobileMenu = false;
	}

	onMount(() => {
		// 点击外部关闭移动端菜单
		function handleClickOutside(event) {
			if (showMobileMenu && !event.target.closest('.mobile-menu') && !event.target.closest('.mobile-menu-button')) {
				showMobileMenu = false;
			}
		}

		document.addEventListener('click', handleClickOutside);
		return () => {
			document.removeEventListener('click', handleClickOutside);
		};
	});
</script>

<div class="app">
	<!-- 导航栏 -->
	<nav class="navbar">
		<div class="nav-container">
			<!-- Logo -->
			<a href="/" class="nav-logo">
				<span class="logo-icon">📊</span>
				<span class="logo-text">日志监控</span>
			</a>

			<!-- 桌面端导航 -->
			<div class="nav-links desktop-nav">
				{#each navItems as item}
					<a 
						href={item.href} 
						class="nav-link"
						class:active={$page.url.pathname === item.href}
					>
						<span class="nav-icon">{item.icon}</span>
						<span class="nav-label">{item.label}</span>
					</a>
				{/each}
			</div>

			<!-- 移动端菜单按钮 -->
			<button class="mobile-menu-button" on:click={toggleMobileMenu} aria-label="切换菜单">
				<span class="hamburger"></span>
				<span class="hamburger"></span>
				<span class="hamburger"></span>
			</button>
		</div>

		<!-- 移动端导航菜单 -->
		{#if showMobileMenu}
			<div class="mobile-menu">
				{#each navItems as item}
					<a 
						href={item.href} 
						class="mobile-nav-link"
						class:active={$page.url.pathname === item.href}
						on:click={closeMobileMenu}
					>
						<span class="nav-icon">{item.icon}</span>
						<span class="nav-label">{item.label}</span>
					</a>
				{/each}
			</div>
		{/if}
	</nav>

	<!-- 主内容区域 -->
	<main class="main-content">
		<slot />
	</main>

	<!-- 页脚 -->
	<footer class="footer">
		<div class="footer-content">
			<p>&copy; 2024 日志监控系统. 基于 Vert.x + Kotlin + SvelteKit 构建</p>
			<div class="footer-links">
				<a href="https://github.com" target="_blank" rel="noopener noreferrer">GitHub</a>
				<a href="/docs" target="_blank" rel="noopener noreferrer">文档</a>
				<a href="/api" target="_blank" rel="noopener noreferrer">API</a>
			</div>
		</div>
	</footer>
</div>

<style>
	.app {
		min-height: 100vh;
		display: flex;
		flex-direction: column;
	}

	/* 导航栏样式 */
	.navbar {
		background: rgba(0, 0, 0, 0.8);
		backdrop-filter: blur(10px);
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
		position: sticky;
		top: 0;
		z-index: 100;
	}

	.nav-container {
		max-width: 1200px;
		margin: 0 auto;
		padding: 0 1rem;
		display: flex;
		align-items: center;
		justify-content: space-between;
		height: 60px;
	}

	.nav-logo {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		text-decoration: none;
		color: white;
		font-weight: bold;
		font-size: 1.2rem;
	}

	.logo-icon {
		font-size: 1.5rem;
	}

	.logo-text {
		color: #667eea;
	}

	.desktop-nav {
		display: flex;
		gap: 0.5rem;
	}

	.nav-link {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		border-radius: 8px;
		text-decoration: none;
		color: rgba(255, 255, 255, 0.8);
		transition: all 0.2s;
		font-size: 0.9rem;
	}

	.nav-link:hover {
		background: rgba(255, 255, 255, 0.1);
		color: white;
	}

	.nav-link.active {
		background: rgba(102, 126, 234, 0.2);
		color: #667eea;
	}

	.nav-icon {
		font-size: 1rem;
	}

	.nav-label {
		font-weight: 500;
	}

	/* 移动端菜单按钮 */
	.mobile-menu-button {
		display: none;
		flex-direction: column;
		background: none;
		border: none;
		cursor: pointer;
		padding: 0.5rem;
		gap: 3px;
	}

	.hamburger {
		width: 20px;
		height: 2px;
		background: white;
		transition: all 0.3s;
	}

	/* 移动端菜单 */
	.mobile-menu {
		position: absolute;
		top: 100%;
		left: 0;
		right: 0;
		background: rgba(0, 0, 0, 0.95);
		backdrop-filter: blur(10px);
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
		padding: 1rem;
		display: none;
	}

	.mobile-nav-link {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1rem;
		border-radius: 8px;
		text-decoration: none;
		color: rgba(255, 255, 255, 0.8);
		margin-bottom: 0.5rem;
		transition: all 0.2s;
	}

	.mobile-nav-link:hover {
		background: rgba(255, 255, 255, 0.1);
		color: white;
	}

	.mobile-nav-link.active {
		background: rgba(102, 126, 234, 0.2);
		color: #667eea;
	}

	/* 主内容区域 */
	.main-content {
		flex: 1;
		min-height: calc(100vh - 120px);
	}

	/* 页脚样式 */
	.footer {
		background: rgba(0, 0, 0, 0.5);
		border-top: 1px solid rgba(255, 255, 255, 0.1);
		padding: 2rem 0;
		margin-top: auto;
	}

	.footer-content {
		max-width: 1200px;
		margin: 0 auto;
		padding: 0 1rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-wrap: wrap;
		gap: 1rem;
	}

	.footer-content p {
		margin: 0;
		color: rgba(255, 255, 255, 0.6);
		font-size: 0.875rem;
	}

	.footer-links {
		display: flex;
		gap: 1rem;
	}

	.footer-links a {
		color: rgba(255, 255, 255, 0.6);
		text-decoration: none;
		font-size: 0.875rem;
		transition: color 0.2s;
	}

	.footer-links a:hover {
		color: #667eea;
	}

	/* 响应式设计 */
	@media (max-width: 768px) {
		.desktop-nav {
			display: none;
		}

		.mobile-menu-button {
			display: flex;
		}

		.mobile-menu {
			display: block;
		}

		.nav-container {
			padding: 0 1rem;
		}

		.logo-text {
			display: none;
		}

		.footer-content {
			flex-direction: column;
			text-align: center;
		}

		.footer-links {
			justify-content: center;
		}
	}

	@media (max-width: 480px) {
		.nav-container {
			height: 50px;
		}

		.nav-logo {
			font-size: 1rem;
		}

		.logo-icon {
			font-size: 1.2rem;
		}
	}
</style> 