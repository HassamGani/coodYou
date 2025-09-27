import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if let halls = vm.diningHalls as [DiningHall]? {
                    List(halls, id: \ .id) { hall in
                        VStack(alignment: .leading) {
                            Text(hall.name).font(.headline)
                            Text(hall.campus).font(.subheadline)
                        }
                        .onTapGesture {
                            vm.selectedHall = hall
                        }
                    }
                } else {
                    Text("Loading halls...")
                }
                Spacer()
            }
            .navigationTitle("CampusDash")
        }
    }
}
