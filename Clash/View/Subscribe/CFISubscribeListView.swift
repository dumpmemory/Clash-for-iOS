import SwiftUI
import ProgressHUD

struct CFISubscribeListView: View {
        
    @EnvironmentObject private var packetTunnelManager: CFIPacketTunnelManager
    @EnvironmentObject private var subscribeManager: CFISubscribeManager
            
    let current: Binding<String>
    
    @State private var isDownloadAlertPresented: Bool = false
    @State private var subscribeURLString: String = ""
        
    @State private var isRenameAlertPresented = false
    @State private var subscribe: CFISubscribe?
    @State private var subscribeName: String = ""
    
    var body: some View {
        NavigationStack {
            List(subscribeManager.subscribes) { subscribe in
                Button {
                    guard current.wrappedValue != subscribe.id else {
                        return
                    }
                    current.wrappedValue = subscribe.id
                } label: {
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subscribe.extend.alias)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            Text(subscribe.extend.leastUpdated.formatted(.relative(presentation: .named)))
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                                .font(.callout)
                                .fontWeight(.light)
                        }
                        Spacer()
                        if current.wrappedValue == subscribe.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                                .fontWeight(.medium)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("删除", role: .destructive) {
                        do {
                            try subscribeManager.delete(subscribe: subscribe)
                            if subscribe.id == current.wrappedValue {
                                current.wrappedValue = ""
                            }
                        } catch {
                            debugPrint(error.localizedDescription)
                        }
                    }
                    Button("重命名") {
                        self.subscribeName = subscribe.extend.alias
                        self.subscribe = subscribe
                        self.isRenameAlertPresented.toggle()
                    }
                    .tint(.yellow)
                    Button("更新") {
                        ProgressHUD.show(interaction: false)
                        Task(priority: .userInitiated) {
                            do {
                                try await subscribeManager.update(subscribe: subscribe)
                                ProgressHUD.showSucceed(interaction: false)
                                if current.wrappedValue == subscribe.id {
                                    packetTunnelManager.set(subscribe: subscribe.id)
                                }
                            } catch {
                                ProgressHUD.showFailed(interaction: false)
                            }
                        }
                    }
                    .tint(.green)
                }
            }
            .navigationTitle(Text("订阅管理"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    subscribeURLString = ""
                    isDownloadAlertPresented.toggle()
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                }
            }
            .alert("重命名", isPresented: $isRenameAlertPresented, presenting: subscribe) { subscribe in
                TextField("请输入订阅名称", text: $subscribeName)
                Button("确定") {
                    let name = subscribeName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !(name == subscribe.extend.alias || name.isEmpty) else {
                        return
                    }
                    do {
                        try subscribeManager.rename(subscribe: subscribe, name: name)
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .alert("订阅", isPresented: $isDownloadAlertPresented) {
                TextField("请输入订阅地址", text: $subscribeURLString)
                Button("确定") {
                    guard let source = URL(string: subscribeURLString) else {
                        return ProgressHUD.showFailed("无效的订阅地址")
                    }
                    ProgressHUD.show(interaction: false)
                    Task(priority: .high) {
                        do {
                            try await subscribeManager.download(source: source)
                            ProgressHUD.dismiss()
                        } catch {
                            ProgressHUD.showFailed(error.localizedDescription)
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}
