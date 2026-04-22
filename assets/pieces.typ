#import "@preview/cetz:0.5.0"

#set page(fill: none, width: auto, height: auto, margin: 0cm)
#set align(center + horizon)


#let piece(clr, moji) = {
  polygon.regular(
    fill: clr.lighten(80%),
    stroke: clr,
    vertices: 6,
    size: 1cm,
  )
  place(horizon + center, moji, dx: 0.1em, dy: -0.1em)
  pagebreak()
}

#{
  piece(green, emoji.bear)
  piece(red, emoji.bear)
  piece(green, emoji.beer)
  piece(red, emoji.beer)
}
