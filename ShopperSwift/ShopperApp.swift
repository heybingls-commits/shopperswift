import SwiftUI
import MapKit
import CoreLocation

let GREEN = Color(red: 0, green: 0.67, blue: 0.28)

@main
struct ShopperApp: App {
    @State private var app = AppState()
    @State private var loc = LocMgr()
    var body: some Scene {
        WindowGroup { RootView().environment(app).environment(loc) }
    }
}

enum Screen { case offline, online, accepted, shopping, checkout, delivering, done }

@Observable
class AppState {
    var screen: Screen = .offline
    var batches: [Batch] = Batch.samples
    var active: Batch?
    var cart: [ItemRow] = []
    var doneCount: Int { cart.filter { $0.status == .found }.count }
    var allDone: Bool { cart.allSatisfy { $0.status != .pending } }

    func goOnline() { screen = .online }
    func goOffline() { screen = .offline; active = nil }
    func accept(_ b: Batch) { active = b; cart = b.items.map { ItemRow(item: $0) }; screen = .accepted }
    func startShop() { screen = .shopping }
    func found(_ r: ItemRow) { if let i = cart.firstIndex(where: { $0.id == r.id }) { cart[i].status = .found } }
    func unavailable(_ r: ItemRow) { if let i = cart.firstIndex(where: { $0.id == r.id }) { cart[i].status = .gone } }
    func replaced(_ r: ItemRow) { if let i = cart.firstIndex(where: { $0.id == r.id }) { cart[i].status = .replaced } }
    func toCheckout() { screen = .checkout }
    func toDelivery() { screen = .delivering }
    func toDone() { screen = .done }
    func reset() { screen = .offline; active = nil; cart = []; batches = Batch.samples }
}

struct ItemRow: Identifiable {
    var id: UUID { item.id }
    var item: BatchItem
    var status: Status = .pending
    enum Status { case pending, found, replaced, gone }
}

@Observable
class LocMgr {
    var auth: CLAuthorizationStatus = .notDetermined
    var coord: CLLocationCoordinate2D?
    private let man = CLLocationManager()
    private let del = LocDel()
    init() {
        auth = man.authorizationStatus
        man.delegate = del
        del.onAuth = { [weak self] s in
            self?.auth = s
            if s == .authorizedWhenInUse || s == .authorizedAlways { self?.man.requestLocation() }
        }
        del.onLoc = { [weak self] c in self?.coord = c }
    }
    func ask() { man.requestWhenInUseAuthorization() }
    var isDenied: Bool { auth == .denied || auth == .restricted }
}

class LocDel: NSObject, CLLocationManagerDelegate {
    var onAuth: ((CLAuthorizationStatus) -> Void)?; var onLoc: ((CLLocationCoordinate2D) -> Void)?
    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) { onAuth?(m.authorizationStatus) }
    func locationManager(_ m: CLLocationManager, didUpdateLocations ls: [CLLocation]) { if let c = ls.first?.coordinate { onLoc?(c) }; m.stopUpdatingLocation() }
    func locationManager(_ m: CLLocationManager, didFailWithError e: Error) { m.stopUpdatingLocation() }
}

struct Batch: Identifiable {
    var id = UUID()
    var store: String; var icon: String; var tint: Color; var addr: String
    var dist: Double; var pay: Double; var tip: Double
    var customer: String; var custAddr: String; var items: [BatchItem]
    var totalPay: Double { pay + tip }

    static let samples = [
        Batch(store: "Whole Foods", icon: "leaf", tint: GREEN, addr: "399 4th St", dist: 1.2, pay: 9.50, tip: 6.40, customer: "Jordan P.", custAddr: "15 Castro St", items: [
            BatchItem("Bananas", 6, "ea", "Produce", "Green OK"), BatchItem("Whole Milk", 1, "gal", "Dairy"), BatchItem("Sourdough Loaf", 1, "ea", "Bakery", "Heaviest loaf")]),
        Batch(store: "Costco", icon: "cart", tint: .red, addr: "450 10th St", dist: 3.1, pay: 11.20, tip: 4.00, customer: "Priya M.", custAddr: "880 Mission", items: [
            BatchItem("Olive Oil 1L", 1, "ea", "Pantry"), BatchItem("Paper Towels 12pk", 1, "ea", "Household")]),
        Batch(store: "Trader Joe's", icon: "bag", tint: .orange, addr: "23 Elm St", dist: 0.9, pay: 7.00, tip: 5.00, customer: "Marco D.", custAddr: "412 Valencia", items: [
            BatchItem("Caesar Salad Kit", 1, "ea", "Produce"), BatchItem("Mandarin Chicken", 2, "ea", "Frozen")]),
        Batch(store: "Safeway", icon: "basket", tint: .blue, addr: "789 Oak Ave", dist: 2.1, pay: 8.40, tip: 6.10, customer: "Linda H.", custAddr: "901 Sutter", items: [
            BatchItem("Salmon Fillet", 1, "lb", "Seafood"), BatchItem("Asparagus", 1, "ea", "Produce")]),
        Batch(store: "Best Buy", icon: "tv", tint: .indigo, addr: "300 Tech Plaza", dist: 1.8, pay: 7.25, tip: 4.50, customer: "Aisha T.", custAddr: "700 Mission", items: [
            BatchItem("HDMI Cable 6ft", 2, "ea", "Electronics"), BatchItem("USB-C Charger 65W", 1, "ea", "Electronics")]),
    ]
}

struct BatchItem: Identifiable {
    var id = UUID()
    var name: String; var qty: Int; var unit: String; var aisle: String; var note: String?
    init(_ n: String, _ q: Int, _ u: String, _ a: String, _ p: String? = nil) { name = n; qty = q; unit = u; aisle = a; note = p }
}

// MARK: - Root
struct RootView: View {
    @Environment(AppState.self) var a
    var body: some View {
        switch a.screen {
        case .offline:      LoungeView()
        case .online:       NavigationStack { DashView() }
        case .accepted:     NavigationStack { AcceptView() }
        case .shopping:     NavigationStack { ShopView() }
        case .checkout:     NavigationStack { CheckView() }
        case .delivering:   NavigationStack { DeliverView() }
        case .done:         NavigationStack { DoneView() }
        }
    }
}

// MARK: - Lounge
struct LoungeView: View {
    @Environment(AppState.self) var a
    @Environment(LocMgr.self) var l
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 6) { Text("Hi, Taylor").font(.title.weight(.bold)); Text("Tap below to start earning").foregroundStyle(.secondary) }
            Spacer().frame(height: 40)
            Button {
                a.goOnline(); if !l.auth.isAuthorized { l.ask() }
            } label: {
                Text("GO ONLINE").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .frame(width: 180, height: 180)
                    .background(Circle().fill(LinearGradient(colors: [GREEN, GREEN.opacity(0.8)], startPoint: .top, endPoint: .bottom)))
                    .shadow(color: GREEN.opacity(0.4), radius: 16, y: 8)
            }
            if l.isDenied { Text("Enable Location in Settings").font(.footnote).foregroundStyle(.secondary).padding(.top, 20) }
            Spacer()
            HStack(spacing: 24) {
                VStack { Text("$184").font(.headline.weight(.bold)); Text("Week").font(.caption).foregroundStyle(.secondary) }
                Divider().frame(height: 36)
                VStack { Text("4.92").font(.headline.weight(.bold)); Text("Rating").font(.caption).foregroundStyle(.secondary) }
                Divider().frame(height: 36)
                VStack { Text("0").font(.headline.weight(.bold)); Text("Today").font(.caption).foregroundStyle(.secondary) }
            }
            .padding().background(.white, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2).padding(.horizontal, 32).padding(.bottom, 60)
        }
        .background(Color(.systemGroupedBackground))
    }
}

extension CLAuthorizationStatus {
    var isAuthorized: Bool { self == .authorizedWhenInUse || self == .authorizedAlways }
}

// MARK: - Dashboard
struct DashView: View {
    @Environment(AppState.self) var a
    var body: some View {
        ScrollView {
            HStack {
                VStack(alignment: .leading) {
                    Text("Online").font(.title.weight(.bold))
                    Text("\(a.batches.count) batch\(a.batches.count == 1 ? "" : "es")").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Go offline", role: .destructive) { a.goOffline() }.font(.subheadline.weight(.semibold))
            }.padding(.horizontal, 20).padding(.vertical, 12)
            LazyVStack(spacing: 14) {
                ForEach(a.batches) { b in
                    BatchCard(b: b).padding(.horizontal, 16)
                }
            }.padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct BatchCard: View {
    @Environment(AppState.self) var a
    let b: Batch
    @State private var time = 240
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack { Circle().fill(b.tint.opacity(0.12)).frame(width: 48, height: 48); Image(systemName: b.icon).font(.title3).foregroundStyle(b.tint) }
                VStack(alignment: .leading) {
                    Text(b.store).font(.title3.weight(.bold))
                    Text("\(b.items.count) items · \(String(format: "%.1f", b.dist)) mi").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(String(format: "$%.2f", b.totalPay)).font(.title2.weight(.bold)).foregroundStyle(GREEN)
                    Text("+$\(String(format: "%.2f", b.tip)) tip").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Text("\(time / 60):\(String(format: "%02d", time % 60))").font(.footnote.weight(.semibold)).foregroundStyle(time < 30 ? .red : .secondary)
                Spacer(); Text("\(b.items.count) items").font(.footnote).foregroundStyle(.secondary)
            }
            Button { a.accept(b) } label: {
                Text("Accept batch").font(.headline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(GREEN, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
            }.buttonStyle(.plain)
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .onReceive(timer) { _ in if time > 0 { time -= 1 } }
    }
}

// MARK: - Accept
struct AcceptView: View {
    @Environment(AppState.self) var a
    var body: some View {
        let b = a.active!
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Head to \(b.store)").font(.title.weight(.bold))
                Map(initialPosition: .region(.init(center: .init(latitude: 37.78, longitude: -122.41), span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012)))) {
                    Marker(b.store, coordinate: .init(latitude: 37.78, longitude: -122.41)).tint(b.tint)
                }.frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 8) {
                    Label(b.addr, systemImage: "mappin.and.ellipse").font(.subheadline)
                    Label("Deliver to \(b.customer)", systemImage: "person.crop.circle").font(.subheadline)
                    Divider()
                    Text("\(b.items.count) items · $\(String(format: "%.2f", b.totalPay))").font(.callout.weight(.semibold))
                    ForEach(b.items.prefix(3)) { item in Text("\(item.qty)× \(item.name)").font(.footnote) }
                    if b.items.count > 3 { Text("+\(b.items.count - 3) more").font(.footnote).foregroundStyle(.secondary) }
                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 12))
                Button { a.startShop() } label: { Text("Start shopping").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14).background(GREEN, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white) }.buttonStyle(.plain)
            }.padding()
        }
        .background(Color(.systemGroupedBackground)).navigationTitle(b.store).navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shopping
struct ShopView: View {
    @Environment(AppState.self) var a
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack {
                    Text("\(a.doneCount) of \(a.cart.count) found").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(a.cart.count > 0 ? a.doneCount * 100 / a.cart.count : 0)%").font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: Double(a.doneCount), total: Double(max(a.cart.count, 1))).tint(GREEN)
            }.padding()
            ScrollView {
                ForEach(grouped, id: \.0) { aisle, rows in
                    VStack(alignment: .leading) {
                        Text(aisle).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 16)
                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                                ItemView(r: r)
                                if i < rows.count - 1 { Divider().padding(.leading, 60) }
                            }
                        }.background(.white, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
                    }.padding(.bottom, 8)
                }
            }
            Button { a.toCheckout() } label: {
                Text(a.allDone ? "Continue to checkout" : "Resolve all items").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(a.allDone ? GREEN : .gray.opacity(0.4), in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
            }.disabled(!a.allDone).buttonStyle(.plain).padding()
        }
        .background(Color(.systemGroupedBackground)).navigationTitle("Shopping").navigationBarTitleDisplayMode(.inline)
    }
    var grouped: [(String, [ItemRow])] { Dictionary(grouping: a.cart) { $0.item.aisle }.sorted { $0.key < $1.key }.map { ($0, $1) } }
}

struct ItemView: View {
    @Environment(AppState.self) var a
    let r: ItemRow
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)).frame(width: 40, height: 40).overlay(Image(systemName: "bag").foregroundStyle(.tertiary))
            VStack(alignment: .leading) {
                Text("\(r.item.qty)× \(r.item.name)").font(.subheadline.weight(.semibold))
                Text(r.item.aisle).font(.caption).foregroundStyle(.secondary)
                if let n = r.item.note { Text(n).font(.caption).foregroundStyle(.blue) }
            }
            Spacer()
            if r.status == .found { Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green) }
            else if r.status == .replaced { Image(systemName: "arrow.triangle.2.circlepath.fill").font(.title3).foregroundStyle(.orange) }
            else if r.status == .gone { Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.red) }
            else {
                Menu {
                    Button("Found it") { a.found(r) }
                    Button("Unavailable") { a.unavailable(r) }
                    Button("Replace") { a.replaced(r) }
                } label: { Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(GREEN) }
            }
        }.padding(10)
    }
}

// MARK: - Checkout / Delivery / Done
struct CheckView: View {
    @Environment(AppState.self) var a
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "barcode.viewfinder").font(.system(size: 64)).foregroundStyle(GREEN)
            Text("At checkout").font(.title.weight(.bold))
            Text("Pay with card on file.").foregroundStyle(.secondary)
            Spacer()
            Button { a.toDelivery() } label: { Text("Pay & head to customer").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14).background(GREEN, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white) }.buttonStyle(.plain).padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle("Checkout").navigationBarTitleDisplayMode(.inline)
    }
}

struct DeliverView: View {
    @Environment(AppState.self) var a
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("To: \(a.active?.customer ?? "")").font(.title2.weight(.bold))
                Text(a.active?.custAddr ?? "").foregroundStyle(.secondary)
                Map(initialPosition: .region(.init(center: .init(latitude: 37.78, longitude: -122.41), span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02)))) {
                    Marker(a.active?.customer ?? "", coordinate: .init(latitude: 37.78, longitude: -122.41)).tint(.purple)
                }.frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 14))
                Button { a.toDone() } label: { Text("Mark as delivered").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14).background(.purple, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white) }.buttonStyle(.plain)
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle("Delivering").navigationBarTitleDisplayMode(.inline)
    }
}

struct DoneView: View {
    @Environment(AppState.self) var a
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack { Circle().fill(GREEN.opacity(0.12)).frame(width: 120, height: 120); Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(GREEN) }
            Text("Delivered!").font(.title.weight(.bold))
            if let b = a.active { Text(String(format: "+$%.2f", b.totalPay)).font(.title2.weight(.semibold)).foregroundStyle(GREEN) }
            Spacer()
            Button { a.reset() } label: { Text("Back to dashboard").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14).background(GREEN, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white) }.buttonStyle(.plain).padding()
        }.background(Color(.systemGroupedBackground))
    }
}
