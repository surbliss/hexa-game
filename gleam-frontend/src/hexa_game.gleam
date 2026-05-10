import lustre
import mvu/model
import mvu/view

pub fn main() {
  let app = lustre.application(model.init, model.update, view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
