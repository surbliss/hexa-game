import gleam/dict
import gleam/list
import gleam/option.{None}
import lustre/effect.{type Effect}
import mvu/types.{
  type Location, type Message, type Model, ClientClickBackground,
  ClientClickIndicator, ClientClickPiece, ClientRequestRestart, Model,
  ServerInitClient, ServerMovePiece, ServerSayHello, ServerShowIndicators,
  Spectator,
}
import server

pub fn init(_args) {
  let model =
    Model(
      pieces: dict.new(),
      indicators: [],
      current_player: None,
      client_role: Spectator,
      // Default until info from server,
    )
  let effect = server.connect(9000)
  #(model, effect)
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    ClientClickPiece(p) -> {
      #(model, server.click_piece(p))
    }
    ClientClickIndicator(l) -> {
      let assert Ok(i) = indicator_index(model.indicators, l)
      #(Model(..model, indicators: []), server.click_indicator(i))
    }
    ClientClickBackground -> {
      #(Model(..model, indicators: []), effect.none())
    }
    // Solely a message for debuggin connection, so fine to leave 'echo'
    ServerSayHello -> {
      echo "Hello server!"
      #(model, effect.none())
    }
    ServerShowIndicators(inds) -> {
      #(Model(..model, indicators: inds), effect.none())
    }
    ServerMovePiece(piece, new_location, new_current_player) -> {
      let pieces = model.pieces |> dict.insert(piece, new_location)
      #(
        Model(
          ..model,
          current_player: new_current_player,
          pieces:,
          // current_player: next_player(model.current_player),
        ),
        effect.none(),
      )
    }
    ServerInitClient(client_role:, piece_locations:, current_player:) -> {
      let pieces = dict.from_list(piece_locations)
      #(Model(..model, pieces:, client_role:, current_player:), effect.none())
    }
    ClientRequestRestart -> {
      #(model, server.restart())
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
