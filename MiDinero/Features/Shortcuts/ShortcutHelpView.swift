import AppIntents
import SwiftUI

struct ShortcutHelpView: View {
    var body: some View {
        List {
            Section("Tu gasto, sin navegar por la app") {
                Text("Abre Atajos y busca MiDinero. Elige Registrar gasto para indicar el monto y la categoría.")
                Text("También puedes decir: «Siri, registrar gasto en MiDinero».")
                ShortcutsLink().frame(minHeight: 44)
            }
            Section("Acceso en la pantalla de inicio") {
                Text("Crea un atajo con la acción Registrar gasto. En monto y categoría elige Preguntar cada vez. Abre los detalles del atajo y toca Añadir a pantalla de inicio.")
            }
            Section("Descripción opcional") {
                Text("La acción admite una descripción, pero no la pregunta por defecto. Puedes escribirla en el editor de Atajos o elegir Preguntar cada vez para ese campo.")
                Text("Para poder omitirla siempre, añade Elegir del menú antes de la acción: Sin descripción o Añadir descripción. En la segunda opción usa Solicitar entrada y pasa ese texto a Descripción.")
            }
            Section("Tus datos") {
                Text("Los gastos se guardan en este iPhone. El atajo requiere que esté desbloqueado. Al abrir MiDinero, las cifras se actualizan con los movimientos guardados.")
            }
        }
        .navigationTitle("Registrar con Atajos")
        .navigationBarTitleDisplayMode(.inline)
    }
}
