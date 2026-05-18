// Websocket
let ws

export function connect(port, openCallback, messageCallback) {
	// Connect to the IP address that hosted the page
	const url = `ws://${window.location.hostname}:${port}`
	ws = new WebSocket(url)
	ws.onopen = () => {
		openCallback()
	}
	ws.onmessage = (e) => {
		messageCallback(e.data)
	}
	ws.onclose = () => {
		setTimeout(() => connect(port, openCallback, messageCallback), 1000)
	}
	ws.onerror = (e) => console.log("Error:", e)
}

export function send(msg) {
	if (ws && ws.readyState === 1) {
		ws.send(msg)
	}
}

