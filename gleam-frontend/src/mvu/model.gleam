import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import lustre/effect.{type Effect}
import mvu/types.{
  type Location, type Message, type Model, type Player, ClientClickBackground,
  ClientClickIndicator, ClientClickPiece, Model, Player, Player1, Player2,
  ServerInitClient, ServerMovePiece, ServerSayHello, ServerShowIndicators,
  Spectator,
}
import server

pub fn init(_args) {
  let model =
    Model(
      pieces: dict.new(),
      indicators: [],
      selected_piece: None,
      current_player: Player1,
      client_role: Spectator,
      // Default until info from server,
    )
  let effect = server.connect("ws://192.168.0.100:9000")
  #(model, effect)
}

fn next_player(player: Player) -> Player {
  case player {
    Player1 -> Player2
    Player2 -> Player1
  }
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    ClientClickPiece(p) -> {
      let selected_piece = case model.client_role {
        Player(x) if p.player == x && model.current_player == x -> Some(p)
        Spectator -> None
        _ -> None
      }
      #(Model(..model, selected_piece:), server.click_piece(p))
    }
    ClientClickIndicator(l) -> {
      let assert Ok(i) = indicator_index(model.indicators, l)
      #(
        Model(..model, indicators: [], selected_piece: None),
        server.click_indicator(i),
      )
    }
    ClientClickBackground -> {
      #(Model(..model, indicators: [], selected_piece: None), effect.none())
    }
    ServerSayHello -> {
      echo "Hello server!"
      #(model, effect.none())
    }
    ServerShowIndicators(inds) -> {
      #(Model(..model, indicators: inds), effect.none())
    }
    ServerMovePiece(piece, new_location) -> {
      let pieces = model.pieces |> dict.insert(piece, new_location)
      #(
        Model(
          ..model,
          pieces:,
          current_player: next_player(model.current_player),
        ),
        effect.none(),
      )
    }
    ServerInitClient(client_role:, piece_locations:) -> {
      let pieces = dict.from_list(piece_locations)
      #(Model(..model, pieces:, client_role:), effect.none())
    }
  }
}

fn indicator_index(
  locations: List(Location),
  location: Location,
) -> Result(Int, Nil) {
  let folder = fn(acc, l, i) {
    case acc {
      Error(Nil) if l == location -> Ok(i)
      _ -> acc
    }
  }
  list.index_fold(locations, Error(Nil), folder)
}
