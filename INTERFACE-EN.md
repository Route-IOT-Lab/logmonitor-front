# API Interface Documentation

## Basic Information

- **Base URL**: `http://localhost:8081`
- **Content Type**: `application/json`
- **Character Encoding**: `UTF-8`

## Common Response Format

All API responses follow a unified format:

```json
{
    "success": true,
    "message": "Operation successful",
    "data": { /* specific data */ },
    "timestamp": 1234567890123
}
```

### Response Field Description

| Field | Type | Description |
|-------|------|-------------|
| success | boolean | Whether the operation was successful |
| message | string | Response message |
| data | object/array | Response data, may be null on failure |
| timestamp | long | Response timestamp |

## Agent Management APIs

### 1. Get Agent List

**Request**
```
GET /api/agents
```

**Response Example**
```json
{
    "success": true,
    "message": "Get agent list successfully",
    "data": [
        {
            "agent": {
                "id": 1,
                "name": "Local Test Agent",
                "host": "127.0.0.1",
                "port": 12315,
                "enabled": true,
                "tags": ["test", "local"],
                "description": "Default test agent",
                "useTls": false,
                "apiKey": null,
                "createdAt": "2025-06-20T11:31:24",
                "updatedAt": "2025-06-20T11:31:24",
                "webSocketUrl": "ws://127.0.0.1:12315"
            },
            "logFiles": [
                {
                    "id": 1,
                    "agentId": 1,
                    "alias": "Test Log File",
                    "filePath": "/var/log/test.log",
                    "enabled": true,
                    "createdAt": "2025-06-20T11:34:20",
                    "updatedAt": "2025-06-20T11:34:20"
                }
            ],
            "monitoringCount": 1,
            "isConnected": false
        }
    ],
    "timestamp": 1750390407722
}
```

### 2. Create Agent

**Request**
```
POST /api/agents
Content-Type: application/json
```

**Request Body**
```json
{
    "name": "New Agent",
    "host": "192.168.1.100",
    "port": 12316,
    "enabled": true,
    "tags": ["production", "server"],
    "description": "Production environment agent",
    "useTls": false,
    "apiKey": null
}
```

**Request Field Description**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Agent name |
| host | string | Yes | Agent host address |
| port | integer | Yes | Agent port number |
| enabled | boolean | No | Whether enabled, default true |
| tags | array | No | Tag list |
| description | string | No | Description |
| useTls | boolean | No | Whether to use TLS, default false |
| apiKey | string | No | API key |

### 3. Update Agent

**Request**
```
PUT /api/agents/{id}
Content-Type: application/json
```

**Request Body** (Same as Create Agent)

### 4. Delete Agent

**Request**
```
DELETE /api/agents/{id}
```

### 5. Connect Agent

**Request**
```
POST /api/agents/{id}/connect
```

### 6. Disconnect Agent

**Request**
```
POST /api/agents/{id}/disconnect
```

## Log File Management APIs

### 1. Get Log File List

**Request**
```
GET /api/agents/{agentId}/logfiles
```

### 2. Add Log File

**Request**
```
POST /api/agents/{agentId}/logfiles
Content-Type: application/json
```

**Request Body**
```json
{
    "filePath": "/var/log/application.log",
    "alias": "Application Log"
}
```

**Request Field Description**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| filePath | string | Yes | Log file path |
| alias | string | Yes | Log file alias |

### 3. Enable Log File Monitoring

**Request**
```
POST /api/agents/{agentId}/logfiles/{alias}/start
```

**Path Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| agentId | integer | Agent ID |
| alias | string | Log file alias (URL encoded) |

### 4. Stop Log File Monitoring

**Request**
```
POST /api/agents/{agentId}/logfiles/{alias}/stop
```

## Log Query APIs

### 1. Get Log Messages (via Query Parameters)

**Request**
```
GET /api/agents/{agentId}/logs?alias={alias}&limit={limit}
```

**Query Parameters**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| alias | string | No | - | Log file alias, returns all if not specified |
| limit | integer | No | 100 | Return count limit |

### 2. Get Log Messages (Direct File Read)

**Request**
```
GET /api/agents/{agentId}/logs/{alias}?tail={lines}
```

**Query Parameters**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| tail | integer | No | 50 | Number of lines from end of file |

**Response Example**
```json
{
    "success": true,
    "message": "Get log messages successfully",
    "data": [
        {
            "id": 1234567890,
            "agentId": 1,
            "logFileAlias": "Test Log File",
            "content": "2025-06-20 11:30:00 INFO Application started",
            "level": "INFO",
            "timestamp": "2025-06-20T11:30:00",
            "createdAt": "2025-06-20T11:30:00"
        }
    ],
    "timestamp": 1750390500000
}
```

## System Status API

### Get System Status

**Request**
```
GET /api/status
```

**Response Example**
```json
{
    "success": true,
    "message": "Get system status successfully",
    "data": {
        "totalAgents": 11,
        "connectedAgents": 0,
        "totalLogFiles": 1,
        "monitoringLogFiles": 1,
        "totalMessages": 0,
        "recentMessages": 0,
        "logLevelStats": []
    },
    "timestamp": 1750390497400
}
```

**Status Field Description**

| Field | Type | Description |
|-------|------|-------------|
| totalAgents | integer | Total number of agents |
| connectedAgents | integer | Number of connected agents |
| totalLogFiles | integer | Total number of log files |
| monitoringLogFiles | integer | Number of monitoring log files |
| totalMessages | long | Total message count |
| recentMessages | long | Recent message count |
| logLevelStats | array | Log level statistics |

## WebSocket API

### Connect to WebSocket

**Connection URL**
```
ws://localhost:8081/ws
```

### Message Formats

#### 1. Subscribe to Agent Logs

**Send Message**
```json
{
    "type": "SUBSCRIBE_AGENT",
    "data": {
        "agentId": 1,
        "logFileAlias": "Test Log File"
    }
}
```

#### 2. Unsubscribe

**Send Message**
```json
{
    "type": "UNSUBSCRIBE_AGENT",
    "data": {
        "agentId": 1,
        "logFileAlias": "Test Log File"
    }
}
```

#### 3. Receive Log Messages

**Receive Message**
```json
{
    "type": "LOG_MESSAGE",
    "data": {
        "agentId": 1,
        "alias": "Test Log File",
        "content": "2025-06-20 11:30:00 INFO Application started",
        "timestamp": "2025-06-20T11:30:00",
        "level": "INFO"
    }
}
```

#### 4. Receive Agent Status

**Receive Message**
```json
{
    "type": "AGENT_STATUS",
    "data": {
        "agentId": 1,
        "isConnected": true
    }
}
```

## Error Handling

### Error Response Format

```json
{
    "success": false,
    "message": "Error description",
    "data": null,
    "timestamp": 1750390500000
}
```

### Common HTTP Status Codes

| HTTP Status Code | Description |
|------------------|-------------|
| 200 | Success |
| 400 | Bad request parameters |
| 404 | Resource not found |
| 500 | Internal server error |

### Error Examples

**Agent Not Found**
```json
{
    "success": false,
    "message": "Agent not found",
    "data": null,
    "timestamp": 1750390500000
}
```

**Parameter Validation Failed**
```json
{
    "success": false,
    "message": "Agent name cannot be empty",
    "data": null,
    "timestamp": 1750390500000
}
```

## Usage Examples

### JavaScript/TypeScript Example

```javascript
// Get agent list
async function getAgents() {
    const response = await fetch('/api/agents');
    const result = await response.json();
    
    if (result.success) {
        console.log('Agents:', result.data);
    } else {
        console.error('Error:', result.message);
    }
}

// Create agent
async function createAgent(agentData) {
    const response = await fetch('/api/agents', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(agentData)
    });
    
    const result = await response.json();
    return result;
}

// WebSocket connection
const ws = new WebSocket('ws://localhost:8081/ws');

ws.onopen = () => {
    console.log('WebSocket connection established');
    
    // Subscribe to agent logs
    ws.send(JSON.stringify({
        type: 'SUBSCRIBE_AGENT',
        data: {
            agentId: 1,
            logFileAlias: 'Test Log File'
        }
    }));
};

ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    console.log('Received message:', message);
};
```

### cURL Examples

```bash
# Get agent list
curl -X GET http://localhost:8081/api/agents

# Create agent
curl -X POST http://localhost:8081/api/agents \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Agent",
    "host": "127.0.0.1",
    "port": 12315,
    "enabled": true,
    "tags": ["test"],
    "description": "Test agent"
  }'

# Add log file
curl -X POST http://localhost:8081/api/agents/1/logfiles \
  -H "Content-Type: application/json" \
  -d '{
    "filePath": "/var/log/test.log",
    "alias": "Test Log"
  }'

# Enable log monitoring
curl -X POST http://localhost:8081/api/agents/1/logfiles/Test%20Log/start

# Get system status
curl -X GET http://localhost:8081/api/status
``` 