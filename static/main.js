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

/// Setup connection!
let send = () => {} // Override inside the 'connect' closure
const connect = () => {
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
				console.log("initial positions")
				console.log(args)
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

const ids = Array.from({ length: 12 }, (_, i) => i) // 0 .. 11
const pieceId = (id) => `piece-${id}`
const indicatorId = (id) => `indicator-${id}`
const pieces = ids.map((id) => document.getElementById(pieceId(id)))

pieces.forEach((h) => {
	h.style.display = "none"
})

const sqrt3 = Math.sqrt(3)
const getHexCoord = (x, y, z) => {
	const scale = 75
	const newX = (x / 2) * sqrt3 + z * 0.05
	const newY = y + x / 2 + z * 0.07
	return [newX * scale, -newY * scale]
}

// Hex for 'indicator' (where to move). Need ID too!:
const board = document.getElementById("board")
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
const removeIndicators = () => {
	document.querySelectorAll(".indicator").forEach((el) => {
		el.remove()
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
	if (z > 0) board.appendChild(h)
}

window.addEventListener("resize", () =>
	board.setAttribute(
		"transform",
		`translate(${window.innerWidth / 2}, ${window.innerHeight / 2})`,
	),
)

board.setAttribute(
	"transform",
	`translate(${window.innerWidth / 2}, ${window.innerHeight / 2})`,
)
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
