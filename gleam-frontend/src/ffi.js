// Websocket
let ws

export function connect(url, openCallback, messageCallback) {
	// console.log("Connecting to", url)
	ws = new WebSocket(url)
	ws.onopen = () => {
		// 	console.log("Connected!")
		openCallback()
	}
	ws.onmessage = (e) => {
		// 	console.log(`Recieved: ${e.data}`)
		messageCallback(e.data)
	}
	ws.onclose = () => {
		// 	console.log("Disconnected, retrying...")
		setTimeout(() => connect(url, openCallback, messageCallback), 1000)
	}
	// ws.onerror = (e) => console.log("Error:", e)
}

export function send(msg) {
	if (ws && ws.readyState === 1) {
		// 	console.log(`Sending: ${msg}`)
		ws.send(msg)
	}
}
