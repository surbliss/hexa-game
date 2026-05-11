import gleam/dict.{type Dict}
import gleam/option.{type Option}

/// NEXT: Split model into 'GameModel' and 'TitleModel'
pub type Model {
  // InGame(GameModel)
  // GameOver(EndScreenModel)
  Model(
    pieces: Dict(Piece, Location),
    indicators: List(Location),
    selected_piece: Option(Piece),
    current_player: Player,
    client_role: ClientRole,
  )
}

pub type ClientRole {
  Player(Player)
  Spectator
}

pub type Message {
  ClientClickPiece(clicked_piece: Piece)
  ClientClickIndicator(indicator_location: Location)
  ClientClickBackground
  ServerSayHello
  ServerMovePiece(piece: Piece, new_location: Location)
  // Add later
  // ServerRegisteredClient
  ServerShowIndicators(indicator_locations: List(Location))
  ServerInitClient(
    client_role: ClientRole,
    piece_locations: List(#(Piece, Location)),
  )
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

pub type Player {
  Player1
  Player2
}

pub type Location {
  Location(x: Int, y: Int, z: Int)
}
