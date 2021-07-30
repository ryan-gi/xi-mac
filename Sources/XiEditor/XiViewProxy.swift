// Copyright 2018 The xi-editor Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

enum SelectionModifier: String {
    case none
    case set
    case add
    case addRemovingCurrent = "add_removing_current"
}

protocol XiViewProxy: AnyObject {
    func resize(size: CGSize)

    func paste(characters: String)
    func copy() -> String?
    func cut() -> String?

    /// Notifies the back-end of the visible scroll region, defined as the first and last
    /// (non-inclusive) formatted lines. The visible scroll region is used to compute movement
    /// distance for page up and page down commands, and also controls the size of the fragment
    /// sent in the update method.
    func scroll(firstLine: Int, lastLine: Int)

    func toggleRecording(name: String)
    func playRecording(name: String)
    func clearRecording(name: String)

    /// Selects the previous occurrence matching the search query.
    func findPrevious(wrapAround: Bool, allowSame: Bool, modifySelection: SelectionModifier)
    /// Selects the next occurrence matching the search query.
    func findNext(wrapAround: Bool, allowSame: Bool, modifySelection: SelectionModifier)
    // This find command supports multiple search queries.
    func multiFind(queries: [FindQuery])
    /// Selects all occurrences matching the search query.
    func findAll()
    /// Shows/hides active search highlights.
    func highlightFind(visible: Bool)

    /// Sets the replacement string.
    func replace(chars: String)
    /// Replaces the next matching occurrence with the replacement string.
    func replaceNext()
    /// Replaces all matching occurrences with the replacement string.
    func replaceAll()

    /// Sets the current selection as the search query.
    func selectionForFind(caseSensitive: Bool)
    /// Sets the current selection as the replacement string.
    func selectionForReplace(caseSensitive: Bool)

    /// Inserts the chars string at the current cursor locations.
    func insert(chars: String)
    /// Deletes backwards.
    func deleteBackward()

    /// transformations
    /// The following methods act by modifying the current selection.
    func uppercase()
    func lowercase()
    func capitalize()
    func indent()
    func outdent()
    func reindent()
}

final class XiViewConnection: XiViewProxy {

    typealias AsyncRpc = (_ method: String, _ params: Any, _ callback: RpcCallback?) -> Void
    typealias SyncRpc = (_ method: String, _ params: Any) -> RpcResult

    private let asyncRpc: AsyncRpc
    private let syncRpc: SyncRpc

    init(asyncRpc: @escaping AsyncRpc, syncRpc: @escaping SyncRpc) {
        self.asyncRpc = asyncRpc
        self.syncRpc = syncRpc
    }

    func resize(size: CGSize) {
        sendRpcAsync("resize", params: ["width": size.width, "height": size.height])
    }
    
    func paste(characters: String) {
        sendRpcAsync("paste", params: ["chars": characters])
    }
    
    func copy() -> String? {
        let copiedString = sendCutCopy("copy")
        return copiedString
    }
    
    func cut() -> String? {
        let cutString = sendCutCopy("cut")
        return cutString
    }
    
    private func sendCutCopy(_ method: String) -> String? {
        let result = sendRpc(method, params: [])
        
        switch result {
        case .ok(let text):
            return text as? String
        case .error(let err):
            print("\(method) failed: \(err)")
            return nil
        }
    }

    func scroll(firstLine: Int, lastLine: Int) {
        sendRpcAsync("scroll", params: [firstLine, lastLine])
    }

    func toggleRecording(name: String) {
        sendRpcAsync("toggle_recording", params: ["recording_name": name])
    }

    func playRecording(name: String) {
        sendRpcAsync("play_recording", params: ["recording_name": name])
    }

    func clearRecording(name: String) {
        sendRpcAsync("clear_recording", params: ["recording_name": name])
    }

    func findPrevious(wrapAround: Bool, allowSame: Bool, modifySelection: SelectionModifier) {
        let params = createFindParamsFor(wrapAround: wrapAround, allowSame: allowSame, modifySelection: modifySelection)
        sendRpcAsync("find_previous", params: params)
    }

    func findNext(wrapAround: Bool, allowSame: Bool, modifySelection: SelectionModifier) {
        let params = createFindParamsFor(wrapAround: wrapAround, allowSame: allowSame, modifySelection: modifySelection)
        sendRpcAsync("find_next", params: params)
    }

    // MARK: - transformations

    func uppercase() {
        sendRpcAsync("uppercase", params: [])
    }

    func lowercase() {
        sendRpcAsync("lowercase", params: [])
    }

    func capitalize() {
        sendRpcAsync("capitalize", params: [])
    }

    func indent() {
        sendRpcAsync("indent", params: [])
    }

    func outdent() {
        sendRpcAsync("outdent", params: [])
    }

    func reindent() {
        sendRpcAsync("reindent", params: [])
    }

    /// All parameters are optional. Boolean parameters are by default `false` and `modify_selection` is `set` by default.
    private func createFindParamsFor(wrapAround: Bool, allowSame: Bool, modifySelection: SelectionModifier) -> [String: Any] {
        var params: [String: Any] = [:]
        if wrapAround {
            params["wrap_around"] = wrapAround
        }
        if allowSame {
            params["allow_same"] = allowSame
        }
        if modifySelection != .set {
            params["modify_selection"] = modifySelection.rawValue
        }
        return params
    }

    func multiFind(queries: [FindQuery]) {
        let jsonQueries = queries.map { $0.toJson() }
        sendRpcAsync("multi_find", params: ["queries": jsonQueries])
    }

    func findAll() {
        sendRpcAsync("find_all", params: [])
    }

    func highlightFind(visible: Bool) {
        sendRpcAsync("highlight_find", params: ["visible": visible])
    }

    func replace(chars: String) {
        sendRpcAsync("replace", params: ["chars": chars])
    }

    func replaceNext() {
        sendRpcAsync("replace_next", params: [])
    }

    func replaceAll() {
        sendRpcAsync("replace_all", params: [])
    }

    func selectionForFind(caseSensitive: Bool) {
        let params = createSelectionParamsFor(caseSensitive: caseSensitive)
        sendRpcAsync("selection_for_find", params: params)
    }

    func selectionForReplace(caseSensitive: Bool) {
        let params = createSelectionParamsFor(caseSensitive: caseSensitive)
        sendRpcAsync("selection_for_replace", params: params)
    }

    /// The parameter `case_sensitive` is optional and `false` if not set.
    private func createSelectionParamsFor(caseSensitive: Bool) -> [String: Bool] {
        if caseSensitive {
            return ["case_sensitive": caseSensitive]
        } else {
            return [:]
        }
    }

    func insert(chars: String) {
        let params = ["chars": chars]
        sendRpcAsync("insert", params: params)
    }

    func deleteBackward() {
        sendRpcAsync("delete_backward", params: [])
    }

    private func sendRpcAsync(_ method: String, params: Any, callback: RpcCallback? = nil) {
        asyncRpc(method, params, callback)
    }

    private func sendRpc(_ method: String, params: Any) -> RpcResult {
        return syncRpc(method, params)
    }
}
