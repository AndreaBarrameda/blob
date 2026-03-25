import SwiftUI

struct SystemInfoView: View {
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Battery
            HStack {
                Image(systemName: monitor.isCharging ? "battery.100.bolt" : "battery.0")
                    .foregroundColor(.orange)
                VStack(alignment: .leading) {
                    Text("Battery")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(monitor.batteryLevel)%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                if monitor.isCharging {
                    Text("Charging")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Divider()

            // Running Apps
            HStack {
                Image(systemName: "app.dashed")
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("Running Apps")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(monitor.runningApps.count) apps")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                Menu {
                    ForEach(monitor.runningApps.prefix(5), id: \.self) { app in
                        Button(app) {}
                    }
                    if monitor.runningApps.count > 5 {
                        Text("...and \(monitor.runningApps.count - 5) more")
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.blue)
                }
                .menuStyle(.borderlessButton)
            }

            Divider()

            // Quick Actions
            HStack(spacing: 8) {
                Button(action: { monitor.increaseVolume() }) {
                    Label("Vol Up", systemImage: "speaker.wave.2.fill")
                        .font(.caption)
                        .padding(6)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button(action: { monitor.decreaseVolume() }) {
                    Label("Vol Down", systemImage: "speaker.fill")
                        .font(.caption)
                        .padding(6)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }
}

#Preview {
    SystemInfoView(monitor: SystemMonitor())
}
