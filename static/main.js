/// API for connecting with socket, i.e. commands possible to send:
// smsg = Message for sending
const smsgConnect = "connect"
const smsgClick = "click" // click i
const smsgClickIndicator = "click-indicator" // click i
// rmsg = Message for recieving
const rmsgMove = "move"
const rmsgHello = "hello" // hello i
const rmsgInit = "init" // init _player-id_ _pos1_ _pos2_ ...
/// TODO: Indicators need an ID also, so that can be referred to when sending back
const rmsgShowIndicators = "show-indicators" // show-indicators x1,y1 x2,y2 ...

const ids = Array.from({ length: 22 }, (_, i) => i) // 0 .. 11
const pieceId = (id) => `piece-${id}`
const indicatorId = (id) => `indicator-${id}`
const pieces = ids.map((id) => document.getElementById(pieceId(id)))

const board = document.getElementById("board")
const stockYou = document.getElementById("stock-you")
const stockEnemy = document.getElementById("stock-enemy")

/// Setup connection!
let send = () => {} // Override inside the 'connect' closure
const connect = () => {
	// Move all pieces to the bench
	const stockX = [5, 4, 4, 3, 3, 2, 2, 2, 1, 1, 1] // placement
	const stockZ = [0, 0, 1, 0, 1, 0, 1, 2, 0, 1, 2] // placement
	ids.forEach((id) => {
		const h = pieces[id]
		const z = stockZ[id % 11]
		const w = window.innerWidth
		const x = (stockX[id % 11] / 5.2) * w + z * 11 - w * 0.1

		const y = 0
		if (id < 11) {
			stockYou.appendChild(h)
		} else {
			stockEnemy.appendChild(h)
		}
		h.setAttribute("transform", `translate(${x}, ${y}), scale(0.8)`)
	})
	// Helper function for comma-delimited numbers
	const getNums = (s) => s.split(",").map(Number)
	const ws = new WebSocket("ws://192.168.0.100:9000")
	send = (command, data) => {
		ws.send(`${command} ${data}`)
	}

	ws.onclose = () => {
		removeIndicators()
		send = () => {} // Make send a no-op, when no server is open
		setTimeout(connect, 1000)
	}

	// First, need to setup all hexes correctly.
	ws.onopen = () => {
		// Identifies the player, so you can refresh without killing the game
		const token = localStorage.getItem("player-token") ?? "new"
		send(smsgConnect, token)
	}

	ws.onmessage = (msg) => {
		console.log(msg.data) // Show all messages send!
		const [cmd, ...args] = msg.data.split(" ")
		switch (cmd) {
			case rmsgMove:
				move(getNums(args[0]))
				break
			case rmsgShowIndicators: {
				removeIndicators()
				let i = 0
				args.forEach((a) => {
					const [x, y, z] = getNums(a)
					// TODO: Make index vary (one for each entry)
					addIndicator(i, x, y, z)
					i += 1
				})
				break
			}
			case rmsgHello:
				console.log(`Hello from ${args[0]}!`)
				break
			case rmsgInit: {
				localStorage.setItem("player-token", args[0])
				args.slice(1).forEach((a) => {
					move(getNums(a))
				})
				break
			}
			default:
				console.log("oh no:")
				console.log(msg.data)
				break
		}
	}
}
// Finish connection-setup
connect()

const sqrt3 = Math.sqrt(3)
const getHexCoord = (x, y, z) => {
	const scale = 76
	const newX = (x / 2) * sqrt3 + z * 0.05
	const newY = y + x / 2 + z * 0.07
	return [newX * scale, -newY * scale]
}

const removeIndicators = () => {
	document.querySelectorAll(".indicator").forEach((el) => {
		el.remove()
	})
}

const addIndicator = (i, x, y, z) => {
	const [cx, cy] = getHexCoord(x, y, z)
	const indicator = document.createElementNS(
		"http://www.w3.org/2000/svg",
		"use",
	)
	indicator.setAttribute("href", "#piece")
	indicator.setAttribute("transform", `translate(${cx}, ${cy})`)
	indicator.setAttribute("id", indicatorId(i))
	indicator.style.fill = "rgba(173, 216, 230, 0.5)"
	indicator.style.stroke = "rgba(173, 216, 230, 0.8)"
	indicator.classList.add("indicator")
	board.appendChild(indicator)
	indicator.addEventListener("click", (e) => {
		e.stopPropagation()
		removeIndicators()
		send(smsgClickIndicator, i)
	})
}

const move = (args) => {
	removeIndicators()
	const [id, x, y, z] = args.map(Number)
	console.log(args.map(Number))
	const h = pieces[id]
	const [newX, newY] = getHexCoord(x, y, z)
	h.setAttribute("transform", `translate(${newX}, ${newY})`)
	h.style.display = ""
	board.appendChild(h) // Render on top / move from stock to board
}

const setLayoutPlacement = () => {
	board.setAttribute(
		"transform",
		`translate(${window.innerWidth / 2}, ${window.innerHeight / 2})`,
	)
	stockYou.setAttribute(
		"transform",
		`translate(0, ${window.innerHeight * 0.9})`,
	)
	stockEnemy.setAttribute(
		"transform",
		`translate(0, ${window.innerHeight * 0.1 - 20})`,
	)
}
window.addEventListener("resize", setLayoutPlacement)
setLayoutPlacement()

const field = document.querySelector("svg")

ids.forEach((id) => {
	pieces[id].addEventListener("click", (e) => {
		e.stopPropagation()
		send(smsgClick, id)
	})
})
field.addEventListener("click", () => {
	removeIndicators()
})
