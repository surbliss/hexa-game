//// Module for rendering-logic for pieces and indicators

import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import gleam/string
import lustre/attribute.{type Attribute} as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/keyed
import lustre/element/svg
import lustre/event
import mvu/types.{
  type Location, type Message, type Model, type Piece, type Player, Blue1, Blue2,
  Blue3, ClientClickIndicator, ClientClickPiece, Green1, Green2, Green3, Orange,
  Player, Player1, Player2, Purple1, Purple2, Red1, Red2, Spectator,
}

//-------------------------------------------------
// Public
//-------------------------------------------------
pub fn view(model: Model) -> Element(Message) {
  let background = case model.client_role {
    Player(_) -> "bg-orange-100"
    Spectator -> "bg-mauve-200"
  }
  let elements = case model.current_player, model.client_role {
    None, _ -> [board(model)]
    Some(_), Player(p) -> [restart(), board(model), stock(model, p, "bottom-0")]
    Some(_), Spectator -> [
      stock(model, Player2, "top-0"),
      board(model),
      stock(model, Player1, "bottom-0"),
    ]
  }
  h.div(
    [
      a.class(
        tw_classes([
          background,
          "flex",
          "flex-col",
          "h-screen",
          "w-screen",
          "justify-center",
          "items-start",
          "select-none",
          "touch-none",
        ]),
      ),
      event.on_click(types.ClientClickBackground),
    ],
    elements,
  )
}

//-------------------------------------------------
// Private
//-------------------------------------------------

fn restart() -> Element(Message) {
  h.button(
    [
      event.on_click(types.ClientRequestRestart),
      a.class(
        tw_classes([
          "bg-red-500/80", "absolute top-0 right-0", "hover:bg-red-700",
          "active:bg-red-700", "text-white", "font-bold", "py-1", "px-2",
          "rounded-bl-lg",
        ]),
      ),
    ],
    [h.text("Restart")],
  )
}

// Board, where all pieces and gameplay live
fn board(model: Model) -> Element(Message) {
  let pieces =
    dict.to_list(model.pieces)
    |> list.sort(fn(x, y) { int.compare(x.1.z, y.1.z) })
  let render_pieces =
    pieces
    |> list.map(fn(x) {
      let #(p, l) = x
      #(string.inspect(p), piece_board(p, l, model))
    })
  let indicators =
    model.indicators
    |> list.map(indicator)
  let coords =
    pieces
    |> list.map(pair.second)
    |> list.map(hex_coordinate)
  let dist_center_x =
    coords
    |> list.map(pair.first)
    |> list.map(float.absolute_value)
    |> list.max(float.compare)
  let dist_center_y =
    coords
    |> list.map(pair.second)
    |> list.map(float.absolute_value)
    |> list.max(float.compare)

  let phone_scale = case dist_center_x, dist_center_y {
    Ok(x), Ok(y) if x >. 60.0 || y >. 125.0 -> "scale-150"
    Ok(x), Ok(y) if x >. 50.0 || y >. 80.0 -> "scale-175"
    Ok(x), Ok(y) if x >. 40.0 || y >. 80.0 -> "scale-200"
    _, _ -> "scale-250"
  }
  let laptop_scale = case dist_center_y {
    Ok(y) if y >. 200.0 -> "md:scale-150"
    Ok(y) if y >. 150.0 -> "md:scale-200"
    Ok(y) if y >. 75.0 -> "md:scale-250"
    _ -> "md:scale-300"
  }
  let hex_style =
    a.class(
      tw_classes([
        // Place (0,0) in the middle of the board
        "translate-x-[50vw]",
        "translate-y-[40vh]",
        phone_scale,
        laptop_scale,
        "transition duration-200",
        "will-change-transform",
      ]),
    )

  svg.svg(
    [
      a.class("w-full h-full duration-200"),
    ],
    [
      keyed.namespaced(
        "http://www.w3.org/2000/svg",
        "g",
        // svg.g(
        [hex_style],
        render_pieces,
      ),
      svg.g([hex_style], indicators),
    ],
  )
}

fn stock(model: Model, player: Player, placement: String) -> Element(Message) {
  let is_in_stock = fn(x: #(Piece, any)) {
    dict.has_key(model.pieces, x.0) |> bool.negate
  }
  let placements = list.map(stock_x_z, stock_coordinate)
  let stock_pieces =
    all_pieces(player)
    |> list.zip(placements)
    |> list.filter(is_in_stock)
    |> list.map(fn(x) {
      let #(p, c) = x
      piece_stock(p, c, model)
    })
  let background = case Some(player) == model.current_player {
    True -> "bg-lime-100"
    False -> "bg-olive-500"
  }
  svg.svg(
    [
      a.class(tw_classes(["fixed", placement, "w-full", "h-20", background])),
    ],
    [
      svg.g(
        [a.class("translate-x-[50vw] translate-y-5 scale-200")],
        stock_pieces,
      ),
    ],
  )
}

// Object-render functions
fn piece_board(
  piece: Piece,
  location: Location,
  model: Model,
) -> Element(Message) {
  let style = piece_style(piece, model)
  // Old CSS colors:
  // orange, mediumpurple, indianred, darkseagreen, cornflowerblue
  svg.path([
    event.on_click(ClientClickPiece(piece)) |> event.stop_propagation,
    place(hex_coordinate(location)),
    a.class(
      tw_classes([
        style,
        "transition duration-200",
        "will-change-transform",
      ]),
    ),
    a.attribute("d", hexagon_path),
  ])
}

fn piece_stock(
  piece: Piece,
  placement: #(Float, Float),
  model: Model,
) -> Element(Message) {
  // Old CSS colors:
  // orange, mediumpurple, indianred, darkseagreen, cornflowerblue
  let style = piece_style(piece, model)
  svg.path([
    event.on_click(ClientClickPiece(piece)) |> event.stop_propagation,
    place(placement),
    a.class(tw_classes([style])),
    a.attribute("d", hexagon_path),
  ])
}

fn piece_style(piece: Piece, model: Model) -> String {
  let #(inactive_fill, active_fill) = case piece.player {
    Player1 -> #("fill-neutral-700", "fill-neutral-950")
    Player2 -> #("fill-neutral-50", "fill-neutral-200")
  }
  let #(inactive_stroke, active_stroke) = case piece {
    Orange(_) -> #("stroke-amber-500", "stroke-amber-600")
    Purple1(_) | Purple2(_) -> #("stroke-violet-400", "stroke-violet-600")
    Red1(_) | Red2(_) -> #("stroke-red-700", "stroke-red-900")
    Green1(_) | Green2(_) | Green3(_) -> #("stroke-lime-500", "stroke-lime-700")
    Blue1(_) | Blue2(_) | Blue3(_) -> #("stroke-sky-600", "stroke-sky-800")
  }
  let style = case piece.player, model.client_role {
    p, Player(q) if p == q && Some(p) == model.current_player ->
      tw_classes([
        inactive_fill,
        inactive_stroke,
        "hover:" <> active_fill,
        "active:" <> active_fill,
        "hover:" <> active_stroke,
        "active:" <> active_stroke,
      ])
    _, _ -> tw_classes([inactive_fill, inactive_stroke])
  }
  tw_classes([
    style,
    "stroke-2",
    "origin-center",
    "[transform-box:fill-box]",
  ])
}

fn indicator(location: Location) -> Element(Message) {
  let coord = hex_coordinate(location)

  svg.path([
    event.on_click(ClientClickIndicator(location)) |> event.stop_propagation,
    a.attribute("d", hexagon_path),
    place(coord),
    a.class(
      tw_classes([
        "fill-blue-200/50",
        "stroke-blue-200",
        "[transform-box:fill-box]",
        "stroke-2",
        "origin-center",
      ]),
    ),
  ])
}

// Helper functions for rendering objects
fn tw_classes(styles: List(String)) -> String {
  styles
  |> string.join(" ")
  |> string.trim
}

// Calculated manually
const sqrt3 = 1.732050808

fn hex_coordinate(location: Location) -> #(Float, Float) {
  let x = int.to_float(location.x)
  let y = int.to_float(location.y)
  let z = int.to_float(location.z)
  let scale = 20.0
  let hex_x =
    x /. 2.0 *. sqrt3 +. z *. 0.09
    |> float.multiply(scale)
    |> float.to_precision(2)
  let hex_y =
    y +. x /. 2.0 +. z *. 0.14
    |> float.multiply(scale)
    |> float.negate
    |> float.to_precision(2)
  #(hex_x, hex_y)
}

fn stock_coordinate(x_z: #(Int, Int)) -> #(Float, Float) {
  let #(x, z) = x_z
  let x = int.to_float(x)
  let z = int.to_float(z)

  let w = 160.0
  let x_place = x /. 5.2 *. w +. z *. 4.0 -. w *. 0.1
  #(x_place, 0.0)
}

fn place(coord: #(Float, Float)) -> Attribute(Message) {
  let x = float.to_string(coord.0)
  let y = float.to_string(coord.1)
  let translate_str = "translate(" <> x <> "," <> y <> ")"
  a.attribute("transform", translate_str)
}

fn all_pieces(player: Player) -> List(Piece) {
  let make_pieces = fn(k) { k(player) }
  kinds |> list.map(make_pieces)
}

const kinds = [
  Blue1,
  Blue2,
  Blue3,
  Green1,
  Green2,
  Green3,
  Red1,
  Red2,
  Purple1,
  Purple2,
  Orange,
]

const stock_x_z = [
  #(-2, 0),
  #(-2, 1),
  #(-2, 2),
  #(-1, 0),
  #(-1, 1),
  #(-1, 2),
  #(0, 0),
  #(0, 1),
  #(1, 0),
  #(1, 1),
  #(2, 0),
]

const hexagon_path = "M2.46148 12.8001C2.29321 12.5087 2.20908 12.3629 2.17615 12.208C2.14701 12.0709 2.14701 11.9293 2.17615 11.7922C2.20908 11.6373 2.29321 11.4915 2.46148 11.2001L6.53772 4.13984C6.70598 3.8484 6.79011 3.70268 6.90782 3.5967C7.01196 3.50293 7.13465 3.43209 7.26793 3.38879C7.41856 3.33984 7.58683 3.33984 7.92336 3.33984H16.0758C16.4124 3.33984 16.5806 3.33984 16.7313 3.38879C16.8645 3.43209 16.9872 3.50293 17.0914 3.5967C17.2091 3.70268 17.2932 3.8484 17.4615 4.13984L21.5377 11.2001C21.706 11.4915 21.7901 11.6373 21.823 11.7922C21.8522 11.9293 21.8522 12.0709 21.823 12.208C21.7901 12.3629 21.706 12.5087 21.5377 12.8001L17.4615 19.8604C17.2932 20.1518 17.2091 20.2975 17.0914 20.4035C16.9872 20.4973 16.8645 20.5681 16.7313 20.6114C16.5806 20.6604 16.4124 20.6604 16.0758 20.6604H7.92336C7.58683 20.6604 7.41856 20.6604 7.26793 20.6114C7.13465 20.5681 7.01196 20.4973 6.90782 20.4035C6.79011 20.2975 6.70598 20.1518 6.53772 19.8604L2.46148 12.8001Z"
