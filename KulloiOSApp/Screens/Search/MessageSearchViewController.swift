/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import LibKullo
import UIKit

class MessageSearchViewController: UITableViewController {
    private static let resultCellId = "MessageSearchResultTableViewCell"
    private static let snippetFontNormal = UIFont.systemFont(ofSize: 14)
    private static let snippetFontHighlighted = UIFont.boldSystemFont(ofSize: 14)

    private let searchController = UISearchController(searchResultsController: nil)
    private var results = [KAMessagesSearchResult]()

    private enum Scope: Int {
        case all
        case sent
        case received

        var title: String {
            switch self {
            case .all: return NSLocalizedString("search_scope_all", comment: "")
            case .sent: return NSLocalizedString("search_scope_sent", comment: "")
            case .received: return NSLocalizedString("search_scope_received", comment: "")
            }
        }
    }

    private static let scopes: [Scope] = [.all, .sent, .received]

    var conversationFilter: Int64?

    override func viewDidLoad() {
        super.viewDidLoad()

        definesPresentationContext = true

        // use self-sizing cells
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 140

        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false

        let searchBar = searchController.searchBar
        searchBar.tintColor = colorAccent
        searchBar.scopeButtonTitles = MessageSearchViewController.scopes.map({ $0.title })
        searchBar.selectedScopeButtonIndex = Scope.all.rawValue
        searchBar.delegate = self

        if #available(iOS 11, *) {
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            searchController.hidesNavigationBarDuringPresentation = false
            tableView.tableHeaderView = searchController.searchBar
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    //MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let result = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(
            withIdentifier: MessageSearchViewController.resultCellId,
            for: indexPath) as! MessageSearchTableViewCell

        cell.senderAvatar.layoutIfNeeded()
        cell.senderAvatar.image = KulloConnector.shared.getSenderAvatar(
            result.msgId, size: cell.senderAvatar.frame.size)
        cell.senderAvatar.showAsCircle()

        cell.senderName.text = KulloConnector.shared.getSenderName(result.msgId)
        cell.attachmentIcon.isHidden = !KulloConnector.shared.hasAttachments(result.msgId)
        cell.date.text = result.dateReceived.formatWithSymbolicNames()
        cell.snippet.attributedText = result.renderSnippet(
            normalFont: MessageSearchViewController.snippetFontNormal,
            highlightFont: MessageSearchViewController.snippetFontHighlighted)

        return cell
    }

    //MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = StoryboardUtil.instantiate(MessageViewController.self)
        vc.conversationId = results[indexPath.row].convId
        vc.messageId = results[indexPath.row].msgId
        navigationController?.pushViewController(vc, animated: true)
    }
}

//MARK: - UISearchResultsUpdating

extension MessageSearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        if searchText.isEmpty {
            results.removeAll()
            tableView.reloadData()
        } else {
            let senderPredicate: KASenderPredicate?
            switch Scope(rawValue: searchController.searchBar.selectedScopeButtonIndex)! {
            case .all:
                senderPredicate = nil
            case .sent:
                senderPredicate = KASenderPredicate(
                    predicateOperator: .is,
                    senderAddress: KulloConnector.shared.getClientAddress()
                )
            case .received:
                senderPredicate = KASenderPredicate(
                    predicateOperator: .isNot,
                    senderAddress: KulloConnector.shared.getClientAddress()
                )
            }

            KulloConnector.shared.searchForMessages(
                text: searchText,
                convId: conversationFilter,
                senderPredicate: senderPredicate,
                completion: {

                [weak self] results in
                guard let strongSelf = self else { return }

                strongSelf.results = results
                strongSelf.tableView.reloadData()
            })
        }
    }
}

extension MessageSearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateSearchResults(for: searchController)
    }
}
