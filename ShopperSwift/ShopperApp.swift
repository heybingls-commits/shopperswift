import SwiftUI
import MapKit
import CoreLocation

private let priGreen = Color(red: 0, green: 0.67, blue: 0.28)

@main
struct ShopperApp: App {
    @State private var state = AppState()
    @State private var loc = LocService()
    var body: some Scene {
        WindowGroup { Content().environment(state).environment(loc) }
    }
}

// MARK: - State
enum Phase: Equatable { case offline, online, accepted, shopping, checkout, delivering, done }

@Observable
final class AppState {
    var phase: Phase = .offline
    var orders: [Batch] = mockOrders
    var active: Batch?
    var cart: [ItemRow] = []
    var found: Int { cart.filter { $0.status == .found || $0.status == .replaced }.count }
    var total: Int { cart.count }
    var allDone: Bool { cart.allSatisfy { $0.status != .pending } }

    func goOnline() { phase = .online }
    func goOffline() { phase = .offline; active = nil }
    func accept(_ b: Batch) { active = b; cart = b.items.map { ItemRow(item: $0) }; phase = .accepted }
    func startShop() { phase = .shopping }
    func markFound(_ r: ItemRow) { guard let i = cart.firstIndex(where: { $0.id == r.id }) else { return }; cart[i].status = .found }
    func markGone(_  r: ItemRow) { guard let i = cart.firstIndex(where: { $0.id == r.id }) else { return }; cart[i].status = .gone }
    func replace(_  r: ItemRow, with: String) { guard let i = cart.firstIndex(where: { $0.id == r.id }) else { return }; cart[i].status = .replaced; cart[i].replacement = with }
    func toCheckout() { phase = .checkout }
    func toDeliver()  { phase = .delivering }
    func toDone()     { phase = .done }
    func reset()      { phase = .offline; active = nil; cart = []; orders = mockOrders }
}

struct ItemRow: Identifiable, Hashable {
    var id: UUID { item.id }
    var item: BatchItem
    var status: Status = .pending
    var replacement: String?
    enum Status: String { case pending, found, replaced, gone }
}

@Observable
final class LocService {
    var auth: CLAuthorizationStatus = .notDetermined
    var coord: CLLocationCoordinate2D?
    private let man = CLLocationManager()
    private let del = LocDel()
    init() { auth = man.authorizationStatus; man.delegate = del
        del.onAuth = { [weak self] s in self?.auth = s; if [.authorizedWhenInUse, .authorizedAlways].contains(s) { self?.man.requestLocation() } }
        del.onLoc  = { [weak self] c in self?.coord = c }
    }
    func ask() { man.requestWhenInUseAuthorization() }
    var denied: Bool { auth == .denied || auth == .restricted }
}

final class LocDel: NSObject, CLLocationManagerDelegate {
    var onAuth: ((CLAuthorizationStatus) -> Void)?; var onLoc: ((CLLocationCoordinate2D) -> Void)?
    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) { onAuth?(m.authorizationStatus) }
    func locationManager(_ m: CLLocationManager, didUpdateLocations ls: [CLLocation]) { if let c = ls.first?.coordinate { onLoc?(c) }; m.stopUpdatingLocation() }
    func locationManager(_ m: CLLocationManager, didFailWithError e: Error) { m.stopUpdatingLocation() }
}

// MARK: - Models
struct Batch: Identifiable {
    var id = UUID(); var store: String; var icon: String; var tint: Color; var addr: String; var dist: Double; var pay: Double; var tip: Double
    var customer: String; var custAddr: String; var items: [BatchItem]; var totalPay: Double { pay + tip }
    static let sample = [
        Batch(store: "Whole Foods", icon: "leaf.fill", tint: priGreen, addr: "399 4th St", dist: 1.2, pay: 9.50, tip: 6.40, customer: "Jordan P.", custAddr: "15 Castro St", items: [.init(n: "Bananas", q: 6, u: "ea", a: "Produce", p: "Green OK"), .init(n: "Whole Milk", q: 1, u: "gal", a: "Dairy"), .init(n: "Sourdough Loaf", q: 1, u: "ea", a: "Bakery", p: "Heaviest loaf")]),
        Batch(store: "Costco", icon: "cart.fill", tint: .red, addr: "450 10th St", dist: 3.1, pay: 11.20, tip: 4.00, customer: "Priya M.", custAddr: "880 Mission", items: [.init(n: "Olive Oil 1L", q: 1, u: "ea", a: "Pantry"), .init(n: "Paper Towels 12pk", q: 1, u: "ea", a: "Household")]),
        Batch(store: "Trader Joe's", icon: "tortilla.fill", tint: .orange, addr: "23 Elm St", dist: 0.9, pay: 7.00, tip: 5.00, customer: "Marco D.", custAddr: "412 Valencia", items: [.init(n: "Caesar Salad Kit", q: 1, u: "ea", a: "Produce"), .init(n: "Mandarin Chicken", q: 2, u: "ea", a: "Frozen")]),
        Batch(store: "Safeway", icon: "basket.fill", tint: .blue, addr: "789 Oak Ave", dist: 2.1, pay: 8.40, tip: 6.10, customer: "Linda H.", custAddr: "901 Sutter", items: [.init(n: "Salmon Fillet", q: 1, u: "lb", a: "Seafood"), .init(n: "Asparagus", q: 1, u: "ea", a: "Produce")]),
        Batch(store: "Best Buy", icon: "tv.fill", tint: .indigo, addr: "300 Tech Plaza", dist: 1.8, pay: 7.25, tip: 4.50, customer: "Aisha T.", custAddr: "700 Mission", items: [.init(n: "HDMI Cable 6ft", q: 2, u: "ea", a: "Electronics"), .init(n: "USB-C Charger 65W", q: 1, u: "ea", a: "Electronics")]),
    ]
}
let mockOrders = Batch.sample

struct BatchItem: Identifiable, Hashable {
    var id = UUID(); var name: String; var qty: Int; var unit: String; var aisle: String; var note: String?
    init(n: String, q: Int, u: String, a: String, p: String? = nil) { name = n; qty = q; unit = u; aisle = a; note = p }
}

// MARK: - Root
struct Content: View {
    @Environment(AppState.self) private var s
    var body: some View {
        switch s.phase {
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
    @Environment(AppState.self) private var s
    @Environment(LocService.self) private var l
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 6) {
                Text("Hi, Taylor").font(.title.weight(.bold))
                Text("Tap below to start earning").foregroundStyle(.secondary)
            }
            Spacer().frame(height: 40)
            Button {
                s.goOnline()
                if l.auth != .authorizedWhenInUse && l.auth != .authorizedAlways { l.ask() }
            } label: {
                Text("GO ONLINE")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 180, height: 180)
                    .background(Circle().fill(LinearGradient(colors: [priGreen, priGreen.opacity(0.8)], startPoint: .top, endPoint: .bottom)))
                    .shadow(color: priGreen.opacity(0.4), radius: 16, y: 8)
            }
            if l.denied {
                Text("Enable Location in Settings").font(.footnote).foregroundStyle(.secondary).padding(.top, 20)
            }
            Spacer()
            HStack(spacing: 24) {
                stat("$184", "This week"); Divider().frame(height: 36); stat("4.92", "Rating"); Divider().frame(height: 36); stat("0", "Today")
            }
            .padding().background(.white, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2).padding(.horizontal, 32).padding(.bottom, 60)
        }
        .background(Color(.systemGroupedBackground))
    }
    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) { Text(v).font(.headline.weight(.bold)); Text(l).font(.caption).foregroundStyle(.secondary) }
    }
}

// MARK: - Dashboard
struct DashView: View {
    @Environment(AppState.self) private var s
    var body: some View {
        ScrollView {
            HStack {
                VStack(alignment: .leading) {
                    Text("Online").font(.title.weight(.bold))
                    Text("\(s.orders.count) batch\(s.orders.count != 1 ? "es" : "") available").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Go offline", role: .destructive) { s.goOffline() }.font(.subheadline.weight(.semibold))
            }.padding(.horizontal, 20).padding(.vertical, 12)

            LazyVStack(spacing: 14) {
                ForEach(s.orders) { batch in
                    BatchCard(b: batch).padding(.horizontal, 16)
                }
            }.padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct BatchCard: View {
    @Environment(AppState.self) private var s
    let b: Batch
    @State private var secs = 240
    let t = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
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
                    Text(String(format: "$%.2f", b.totalPay)).font(.title2.weight(.bold)).foregroundStyle(priGreen)
                    Text("+$\(String(format: "%.2f", b.tip)) tip").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Text("\(secs / 60):\(String(format: "%02d", secs % 60))").font(.footnote.weight(.semibold)).foregroundStyle(secs < 30 ? .red : .secondary)
                Spacer()
                Text("\(b.items.count) items").font(.footnote).foregroundStyle(.secondary)
            }
            Button { s.accept(b) } label: {
                Text("Accept batch").font(.headline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(priGreen, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
            }.buttonStyle(.plain)
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .onReceive(t) { _ in if secs > 0 { secs -= 1 } }
    }
}

// MARK: - Accepted
struct AcceptView: View {
    @Environment(AppState.self) private var s
    private var b: Batch { s.active! }
    var body: some View {
        ScrollView {
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
                    ForEach(b.items.prefix(3)) { item in
                        Text("\(item.qty)× \(item.name)").font(.footnote)
                    }
                    if b.items.count > 3 { Text("+\(b.items.count - 3) more").font(.footnote).foregroundStyle(.secondary) }
                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 12))

                Button { s.startShop() } label: {
                    Text("Start shopping").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(priGreen, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                }.buttonStyle(.plain)
            }.padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(b.store).navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shopping
struct ShopView: View {
    @Environment(AppState.self) private var s
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack {
                    Text("\(s.found) of \(s.total) found").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(s.total > 0 ? s.found * 100 / s.total : 0)%").font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: Double(s.found), total: Double(max(s.total, 1))).tint(priGreen)
            }.padding()

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(grouped, id: \.0) { aisle, rows in
                        Section {
                            VStack(spacing: 0) {
                                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                                    RowView(r: row)
                                    if i < rows.count - 1 { Divider().padding(.leading, 60) }
                                }
                            }.background(.white, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16).padding(.bottom, 12)
                        } header: {
                            Text(aisle).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 8)
                                .background(Color(.systemGroupedBackground))
                        }
                    }
                }
            }

            Button { s.toCheckout() } label: {
                Text(s.allDone ? "Continue to checkout" : "Resolve all items first")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(s.allDone ? priGreen : .gray.opacity(0.4), in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
            }.disabled(!s.allDone).buttonStyle(.plain).padding()
        }
        .background(Color(.systemGroupedBackground
