import type { WebSocketMessage } from '../types';

export class WebSocketService {
	private ws: WebSocket | null = null;
	private reconnectAttempts = 0;
	private maxReconnectAttempts = 5;
	private reconnectDelay = 1000;
	private listeners: Map<string, ((data: any) => void)[]> = new Map();
	private url: string;

	constructor(url = 'ws://localhost:8081/ws') {
		this.url = url;
	}

	connect(): Promise<void> {
		return new Promise((resolve, reject) => {
			try {
				console.log('🔍 Connecting to WebSocket:', this.url);
				this.ws = new WebSocket(this.url);

				// 设置连接超时
				const connectionTimeout = setTimeout(() => {
					if (this.ws && this.ws.readyState === WebSocket.CONNECTING) {
						console.error('❌ WebSocket connection timeout');
						this.ws.close();
						reject(new Error('WebSocket connection timeout'));
					}
				}, 5000); // 5秒超时

				this.ws.onopen = () => {
					clearTimeout(connectionTimeout);
					console.log('✅ WebSocket connected successfully');
					this.reconnectAttempts = 0;
					resolve();
				};

				this.ws.onmessage = (event) => {
					try {
						console.log('🔍 Raw WebSocket message received:', event.data);
						const message: WebSocketMessage = JSON.parse(event.data);
						this.handleMessage(message);
					} catch (error) {
						console.error('❌ Failed to parse WebSocket message:', error);
						console.error('🔍 Raw message data:', event.data);
					}
				};

				this.ws.onclose = (event) => {
					clearTimeout(connectionTimeout);
					console.log('WebSocket disconnected:', event.code, event.reason);
					this.ws = null;
					
					// 如果不是主动关闭，尝试重连
					if (event.code !== 1000 && this.reconnectAttempts < this.maxReconnectAttempts) {
						this.scheduleReconnect();
					}
				};

				this.ws.onerror = (error) => {
					clearTimeout(connectionTimeout);
					console.error('WebSocket error:', error);
					reject(error);
				};
			} catch (error) {
				reject(error);
			}
		});
	}

	private scheduleReconnect() {
		this.reconnectAttempts++;
		const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);
		
		console.log(`Attempting to reconnect in ${delay}ms (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
		
		setTimeout(() => {
			this.connect().catch(console.error);
		}, delay);
	}

	private handleMessage(message: WebSocketMessage) {
		console.log('🔍 WebSocket received raw message:', message);
		console.log('🔍 Message type:', message.type);
		
		const listeners = this.listeners.get(message.type) || [];
		console.log(`🔍 Found ${listeners.length} listeners for type '${message.type}'`);
		
		if (listeners.length === 0) {
			console.warn(`⚠️ No listeners registered for message type: ${message.type}`);
			console.log('🔍 Available message types:', Array.from(this.listeners.keys()));
		}
		
		listeners.forEach((listener, index) => {
			try {
				console.log(`🔍 Calling listener ${index + 1} for type '${message.type}'`);
				
				// 对于扁平结构的消息（如log消息），直接传递整个消息对象
				// 对于有data字段的消息，传递data字段
				const dataToPass = message.data !== undefined ? message.data : message;
				
				listener(dataToPass);
				console.log(`✅ Listener ${index + 1} called successfully with data:`, dataToPass);
			} catch (error) {
				console.error(`❌ Error in WebSocket message listener ${index + 1}:`, error);
				console.error('🔍 Message that caused error:', message);
			}
		});
	}

	send(type: string, data: any) {
		if (this.ws && this.ws.readyState === WebSocket.OPEN) {
			const message: WebSocketMessage = { type, data };
			console.log('WebSocket sending message:', message);
			this.ws.send(JSON.stringify(message));
		} else {
			console.warn('WebSocket is not connected, cannot send:', { type, data });
		}
	}

	subscribe(type: string, listener: (data: any) => void) {
		if (!this.listeners.has(type)) {
			this.listeners.set(type, []);
		}
		this.listeners.get(type)!.push(listener);
	}

	unsubscribe(type: string, listener: (data: any) => void) {
		const listeners = this.listeners.get(type);
		if (listeners) {
			const index = listeners.indexOf(listener);
			if (index > -1) {
				listeners.splice(index, 1);
			}
		}
	}

	subscribeToAgent(agentId: number, logFileAlias?: string) {
		this.send('SUBSCRIBE_AGENT', {
			agentId,
			logFileAlias
		});
	}

	unsubscribeFromAgent(agentId: number, logFileAlias?: string) {
		this.send('UNSUBSCRIBE_AGENT', {
			agentId,
			logFileAlias
		});
	}

	disconnect() {
		if (this.ws) {
			this.ws.close(1000, 'Client disconnect');
			this.ws = null;
		}
	}

	isConnected(): boolean {
		return this.ws !== null && this.ws.readyState === WebSocket.OPEN;
	}
}

// 全局WebSocket实例
export const webSocketService = new WebSocketService();
