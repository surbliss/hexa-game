import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import lustre/effect.{type Effect}
import mvu/types.{
  type Location, type Message, type Model, ClientClickBackground,
  ClientClickIndicator, ClientClickPiece, Model, ServerSayHello,
}
import server

pub fn init(_args) {
  let model = Model(pieces: dict.new(), indicators: [], selected_piece: None)
  let effect = server.connect("ws://192.168.0.100:9000")
  #(model, effect)
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    ClientClickPiece(p) -> {
      #(Model(..model, selected_piece: Some(p)), server.click_piece(p))
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
    types.ServerShowIndicators(inds) -> {
      #(Model(..model, indicators: inds), effect.none())
    }
    types.ServerMovePiece(piece, new_location) -> {
      let pieces = model.pieces |> dict.insert(piece, new_location)
      #(Model(..model, pieces:), effect.none())
    }
    types.ServerInitPieces(init_piece_locations) -> {
      let pieces = dict.from_list(init_piece_locations)
      #(Model(..model, pieces:), effect.none())
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
