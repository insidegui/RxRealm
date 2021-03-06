
import UIKit

import RxSwift
import RxCocoa

import RealmSwift
import RxRealm

//realm model
class Lap: Object {
    dynamic var time: TimeInterval = Date().timeIntervalSinceReferenceDate
}

class TickCounter: Object {
    dynamic var id = UUID().uuidString
    dynamic var ticks: Int = 0
    override static func primaryKey() -> String? {return "id"}
}

//view controller
class ViewController: UIViewController {
    let bag = DisposeBag()
    let realm = try! Realm()
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tickItemButton: UIBarButtonItem!
    @IBOutlet weak var addTwoItemsButton: UIBarButtonItem!

    var laps: Results<Lap>!

    let footer: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        return l
    }()

    var ticker: TickCounter!

    override func viewDidLoad() {
        super.viewDidLoad()

        laps = realm.objects(Lap.self).sorted(byProperty: "time", ascending: false)

        /*
         Observable<Results<Lap>> - wrap Results as observable
         */
        Observable.from(laps)
            .map {results in "laps: \(results.count)"}
            .subscribe { event in
                self.title = event.element
            }
            .addDisposableTo(bag)

        /*
         Observable<Results<Lap>> - reacting to change sets
         */
        Observable.changesetFrom(laps)
            .subscribe(onNext: {[unowned self] results, changes in
                if let changes = changes {
                    self.tableView.applyChangeset(changes)
                } else {
                    self.tableView.reloadData()
                }
            })
            .addDisposableTo(bag)
        
        /*
         Use bindable sink to add objects
         */
        addTwoItemsButton.rx.tap
            .map { [Lap(), Lap()] }
            .bindTo(Realm.rx.add())
            .addDisposableTo(bag)

        /*
         Create a ticker object
         */
        ticker = TickCounter()
        try! realm.write {
            realm.add(ticker)
        }

        /*
         Bind bar item to increasing the ticker
         */
        tickItemButton.rx.tap
            .subscribe(onNext: {[unowned self] value in
                try! self.realm.write {
                    self.ticker.ticks += 1
                }
            })
            .addDisposableTo(bag)

        /*
         Observing a single object
         */
        Observable.from(ticker)
            .map({ (ticker) -> String in
                return "\(ticker.ticks) ticks"
            })
            .bindTo(footer.rx.text)
            .addDisposableTo(bag)
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return laps.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let lap = laps[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        cell.textLabel?.text = formatter.string(from: Date(timeIntervalSinceReferenceDate: lap.time))
        return cell
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Observable.from([laps[indexPath.row]])
            .subscribe(Realm.rx.delete())
            .addDisposableTo(bag)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return footer
    }
}

extension UITableView {
    func applyChangeset(_ changes: RealmChangeset) {
        beginUpdates()
        insertRows(at: changes.inserted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        reloadRows(at: changes.updated.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        deleteRows(at: changes.deleted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        endUpdates()
    }
}
