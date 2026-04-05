const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;
const server = require('http').createServer();
const wss = new WebSocket.Server({ server });

server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

const clients = new Set();

wss.on('connection', (ws, req) => {
    const ip = req.socket.remoteAddress.replace(/^::ffff:/, '');
    console.log('Client connected:', ip);
    clients.add(ws);

    ws.on('message', (message) => {
        try {
            const msg = message.toString();
            console.log('Received:', msg);

            // Broadcast to all other clients
            for (let client of clients) {
                if (client !== ws && client.readyState === WebSocket.OPEN) {
                    client.send(msg);
                }
            }
        } catch (e) {
            console.error('Error handling message:', e);
        }
    });

    ws.on('close', () => {
        console.log('Client disconnected');
        clients.delete(ws);
    });

    ws.on('error', (err) => {
        console.error('WebSocket error:', err);
    });
});

console.log(`Relay server running. Accessible via ws://<your-ip>:${PORT}`);