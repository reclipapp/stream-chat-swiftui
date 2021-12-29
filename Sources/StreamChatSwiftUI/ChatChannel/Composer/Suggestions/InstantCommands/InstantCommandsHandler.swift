//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import Combine
import StreamChat
import SwiftUI

public class InstantCommandsHandler: CommandHandler {
    
    public let id: String
    public var displayInfo: CommandDisplayInfo?
    
    private let typingSuggester = TypingSuggester(
        options:
        TypingSuggestionOptions(
            symbol: "/",
            shouldTriggerOnlyAtStart: true
        )
    )
    private let commands: [CommandHandler]
    
    public init(
        commands: [CommandHandler],
        id: String = "instantCommands"
    ) {
        self.commands = commands
        self.id = id
    }
    
    public func canHandleCommand(in text: String, caretLocation: Int) -> ComposerCommand? {
        // Check for instant commands
        for command in commands {
            if let instantCommand = command.canHandleCommand(
                in: text,
                caretLocation: caretLocation
            ) {
                return instantCommand
            }
        }
        
        // Check for instant commands container
        if let typingSuggestion = typingSuggester.typingSuggestion(
            in: text,
            caretLocation: caretLocation
        ) {
            return ComposerCommand(
                id: id,
                typingSuggestion: typingSuggestion,
                displayInfo: nil
            )
        } else {
            return nil
        }
    }
    
    public func canShowSuggestions(for command: ComposerCommand) -> CommandHandler? {
        for instant in commands {
            if instant.canShowSuggestions(for: command) != nil {
                return instant
            }
        }
        
        return command.id == id ? self : nil
    }
    
    public func showSuggestions(for command: ComposerCommand) -> Future<SuggestionInfo, Error> {
        if let handler = canShowSuggestions(for: command), handler.id != id {
            return handler.showSuggestions(for: command)
        }
        let suggestionInfo = SuggestionInfo(key: id, value: commands)
        return resolve(with: suggestionInfo)
    }
    
    public func handleCommand(
        for text: Binding<String>,
        selectedRangeLocation: Binding<Int>,
        command: Binding<ComposerCommand?>,
        extraData: [String: Any]
    ) {
        if let commandValue = command.wrappedValue,
           let handler = canShowSuggestions(for: commandValue), handler.id != id {
            handler.handleCommand(
                for: text,
                selectedRangeLocation: selectedRangeLocation,
                command: command,
                extraData: extraData
            )
            return
        }
        
        guard let instantCommand = extraData["instantCommand"] as? ComposerCommand else {
            return
        }
        command.wrappedValue = instantCommand
    }
    
    public func executeOnMessageSent(
        composerCommand: ComposerCommand,
        completion: @escaping (Error?) -> Void
    ) {
        if let handler = canShowSuggestions(for: composerCommand) {
            handler.executeOnMessageSent(
                composerCommand: composerCommand,
                completion: completion
            )
        }
    }
    
    public func canBeExecuted(composerCommand: ComposerCommand) -> Bool {
        if let handler = canShowSuggestions(for: composerCommand), handler.id != id {
            return handler.canBeExecuted(composerCommand: composerCommand)
        }
        
        return !composerCommand.typingSuggestion.text.isEmpty
    }
}
