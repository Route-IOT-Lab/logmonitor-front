export interface Agent {
	id: number;
	name: string;
	host: string;
	port: number;
	enabled: boolean;
	tags: string[];
	description?: string;
	useTls: boolean;
	apiKey?: string;
	createdAt: string;
	updatedAt: string;
	webSocketUrl: string;
}

export interface LogFile {
	id: number;
	agentId: number;
	alias: string;
	filePath: string;
	enabled: boolean;
	createdAt: string;
	updatedAt: string;
}

export interface AgentDetailView {
	agent: Agent;
	logFiles: LogFile[];
	monitoringCount: number;
	isConnected: boolean;
}

export interface LogMessage {
	id: number;
	agentId: number;
	logFileAlias: string;
	content: string;
	level: string;
	timestamp: string;
	createdAt: string;
}

export interface SystemOverview {
	totalAgents: number;
	connectedAgents: number;
	totalLogFiles: number;
	monitoringLogFiles: number;
	totalMessages: number;
	recentMessages: number;
	logLevelStats: LogLevelStat[];
}

export interface LogLevelStat {
	level: string;
	count: number;
}

export interface ApiResponse<T> {
	success: boolean;
	message: string;
	data?: T;
	timestamp: number;
}

export interface AddAgentRequest {
	name: string;
	host: string;
	port: number;
	enabled: boolean;
	tags: string[];
	description?: string;
	useTls: boolean;
	apiKey?: string;
}

export interface UpdateAgentRequest extends AddAgentRequest {}

export interface AddLogFileRequest {
	filePath: string;
	alias: string;
}

export interface WebSocketMessage {
	type: string;
	data: any;
}
