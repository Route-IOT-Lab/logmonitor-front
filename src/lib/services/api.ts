import type {
	Agent,
	AgentDetailView,
	LogFile,
	LogMessage,
	SystemOverview,
	ApiResponse,
	AddAgentRequest,
	UpdateAgentRequest,
	AddLogFileRequest
} from '../types';

const API_BASE = 'http://localhost:8081/api';

async function apiCall<T>(url: string, options?: RequestInit): Promise<ApiResponse<T>> {
	try {
		const response = await fetch(`${API_BASE}${url}`, {
			headers: {
				'Content-Type': 'application/json',
				...options?.headers
			},
			...options
		});

		if (!response.ok) {
			throw new Error(`HTTP error! status: ${response.status}`);
		}

		return await response.json();
	} catch (error) {
		console.error('API call failed:', error);
		throw error;
	}
}

// Agent相关API
export async function getAgents(): Promise<AgentDetailView[]> {
	const response = await apiCall<AgentDetailView[]>('/agents');
	return response.data || [];
}

export async function getAgent(id: number): Promise<AgentDetailView | null> {
	try {
		const response = await apiCall<AgentDetailView>(`/agents/${id}`);
		return response.data || null;
	} catch (error) {
		console.error('Failed to get agent:', error);
		return null;
	}
}

export async function createAgent(agent: AddAgentRequest): Promise<Agent | null> {
	try {
		const response = await apiCall<Agent>('/agents', {
			method: 'POST',
			body: JSON.stringify(agent)
		});
		return response.data || null;
	} catch (error) {
		console.error('Failed to create agent:', error);
		return null;
	}
}

export async function updateAgent(id: number, agent: UpdateAgentRequest): Promise<Agent | null> {
	try {
		const response = await apiCall<Agent>(`/agents/${id}`, {
			method: 'PUT',
			body: JSON.stringify(agent)
		});
		return response.data || null;
	} catch (error) {
		console.error('Failed to update agent:', error);
		return null;
	}
}

export async function deleteAgent(id: number): Promise<boolean> {
	try {
		await apiCall(`/agents/${id}`, {
			method: 'DELETE'
		});
		return true;
	} catch (error) {
		console.error('Failed to delete agent:', error);
		return false;
	}
}

export async function connectAgent(id: number): Promise<boolean> {
	try {
		await apiCall(`/agents/${id}/connect`, {
			method: 'POST'
		});
		return true;
	} catch (error) {
		console.error('Failed to connect agent:', error);
		return false;
	}
}

export async function disconnectAgent(id: number): Promise<boolean> {
	try {
		await apiCall(`/agents/${id}/disconnect`, {
			method: 'POST'
		});
		return true;
	} catch (error) {
		console.error('Failed to disconnect agent:', error);
		return false;
	}
}

// 日志文件相关API
export async function getLogFiles(agentId: number): Promise<LogFile[]> {
	try {
		const response = await apiCall<LogFile[]>(`/agents/${agentId}/logfiles`);
		return response.data || [];
	} catch (error) {
		console.error('Failed to get log files:', error);
		return [];
	}
}

export async function addLogFile(agentId: number, logFile: AddLogFileRequest): Promise<LogFile | null> {
	try {
		const response = await apiCall<LogFile>(`/agents/${agentId}/logfiles`, {
			method: 'POST',
			body: JSON.stringify(logFile)
		});
		return response.data || null;
	} catch (error) {
		console.error('Failed to add log file:', error);
		return null;
	}
}

export async function startLogFileMonitoring(agentId: number, alias: string): Promise<boolean> {
	try {
		await apiCall(`/agents/${agentId}/logfiles/${encodeURIComponent(alias)}/start`, {
			method: 'POST'
		});
		return true;
	} catch (error) {
		console.error('Failed to start log file monitoring:', error);
		return false;
	}
}

export async function stopLogFileMonitoring(agentId: number, alias: string): Promise<boolean> {
	try {
		await apiCall(`/agents/${agentId}/logfiles/${encodeURIComponent(alias)}/stop`, {
			method: 'POST'
		});
		return true;
	} catch (error) {
		console.error('Failed to stop log file monitoring:', error);
		return false;
	}
}

export async function updateLogFile(agentId: number, oldAlias: string, logFile: AddLogFileRequest): Promise<LogFile | null> {
	try {
		const response = await apiCall<LogFile>(`/agents/${agentId}/logfiles/${encodeURIComponent(oldAlias)}`, {
			method: 'PUT',
			body: JSON.stringify(logFile)
		});
		return response.data || null;
	} catch (error) {
		console.error('Failed to update log file:', error);
		return null;
	}
}

export async function deleteLogFile(agentId: number, alias: string): Promise<boolean> {
	try {
		await apiCall(`/agents/${agentId}/logfiles/${encodeURIComponent(alias)}`, {
			method: 'DELETE'
		});
		return true;
	} catch (error) {
		console.error('Failed to delete log file:', error);
		return false;
	}
}

// 日志消息相关API
export async function getLogMessages(agentId: number, alias?: string, limit = 100): Promise<LogMessage[]> {
	try {
		const params = new URLSearchParams();
		if (alias) params.append('alias', alias);
		params.append('limit', limit.toString());
		
		const response = await apiCall<LogMessage[]>(`/agents/${agentId}/logs?${params}`);
		return response.data || [];
	} catch (error) {
		console.error('Failed to get log messages:', error);
		return [];
	}
}

export async function getLogFileTail(agentId: number, alias: string, tail = 50): Promise<LogMessage[]> {
	try {
		const response = await apiCall<LogMessage[]>(`/agents/${agentId}/logs/${encodeURIComponent(alias)}?tail=${tail}`);
		return response.data || [];
	} catch (error) {
		console.error('Failed to get log file tail:', error);
		return [];
	}
}

// 系统状态API
export async function getSystemStatus(): Promise<SystemOverview | null> {
	try {
		const response = await apiCall<SystemOverview>('/status');
		return response.data || null;
	} catch (error) {
		console.error('Failed to get system status:', error);
		return null;
	}
}
