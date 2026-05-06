export const windowWidth = () => window.innerWidth
export const windowHeight = () => window.innerHeight

let ws

export function connect(url, callback) {
	ws = new WebSocket(url)
	ws.onmessage = (e) => callback(e.data)
	ws.onclose = () => setTimeout(() => connect(url, callback), 1000)
}

export function send(msg) {
	if (ws && ws.readyState === 1) ws.send(msg)
}
