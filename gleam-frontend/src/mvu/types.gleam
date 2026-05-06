import gleam/dict.{type Dict}

pub type Model {
  Model(pieces: Dict(Piece, Location))
}

pub type Message {
  ClientClickedPiece(piece: Piece)
}

pub type Of2 {
  FirstOf2
  SecondOf2
}

pub type Of3 {
  FirstOf3
  SecondOf3
  ThirdOf3
}

pub type Piece {
  Orange(player: Player)
  // IDs below destinguish _which_ of the pieces it is, when there are multiple of the same one
  Purple(player: Player, id: Of2)
  Red(player: Player, id: Of2)
  Green(player: Player, id: Of3)
  Blue(player: Player, id: Of3)
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
