import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type Model {
  Model(
    pieces: Dict(Piece, Location),
    indicators: List(Location),
    selected_piece: Option(Piece),
  )
}

pub type Message {
  ClientClickPiece(piece: Piece)
  ClientClickIndicator(location: Location)
  ClientClickBackground
  ServerSayHello
  ServerMovePiece(piece: Piece, new_location: Location)
  // Add later
  // ServerRegisteredClient
  ServerShowIndicators(indicators: List(Location))
}

pub type Piece {
  Orange(player: Player)
  // IDs below destinguish _which_ of the pieces it is, when there are multiple of the same one
  Purple1(player: Player)
  Purple2(player: Player)
  Red1(player: Player)
  Red2(player: Player)
  Green1(player: Player)
  Green2(player: Player)
  Green3(player: Player)
  Blue1(player: Player)
  Blue2(player: Player)
  Blue3(player: Player)
}

// Client1 = Player1, Client2 = Player2, Spectator for further players, just watching
pub type Client {
  Client1
  Client2
  Spectator
}

pub type Player {
  Player1
  Player2
}

pub type Location {
  Location(x: Int, y: Int, z: Int)
}
