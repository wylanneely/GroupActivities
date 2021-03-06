/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A model that represents the canvas on which to draw.
*/

import Foundation
import Combine
import SwiftUI
import GroupActivities

@MainActor
class Canvas: ObservableObject {
    @Published var strokes = [Stroke]()
    @Published var activeStroke: Stroke?
    let strokeColor = Stroke.Color.random

    var subscriptions = Set<AnyCancellable>()
    var tasks = Set<Task<Void, Never>>()
    
    @Published var groupSession: GroupSession<DrawTogether>?
    var messenger: GroupSessionMessenger?
    
    func addPointToActiveStroke(_ point: CGPoint) {
        let stroke: Stroke
        if let activeStroke = activeStroke {
            stroke = activeStroke
        } else {
            stroke = Stroke(color: strokeColor)
            activeStroke = stroke
        }

        stroke.points.append(point)

        if let messenger = messenger {
            Task {
                do {
                try await messenger.send(UpsertStrokeMessage(id: stroke.id, color: stroke.color, point: point))
                } catch {
                    //handle error
                }
        }
        }
        
    }

    func finishStroke() {
        guard let activeStroke = activeStroke else {
            return
        }

        strokes.append(activeStroke)
        self.activeStroke = nil
    }

    func reset() {
        // Clear local drawing canvas.
        strokes = []

        // Teardown existing groupSession.
        messenger = nil
        tasks.forEach { $0.cancel() }
        tasks = []
        subscriptions = []
        if groupSession != nil {
            groupSession?.leave()
            groupSession = nil
            self.startSharing()
        }
    }

    var pointCount: Int {
        return strokes.reduce(0) { $0 + $1.points.count }
    }

    

    func startSharing() {
        Task {
            do {
                _ = try await DrawTogether().activate()
            } catch {
                print("Failed to activate DrawTogether activity: \(error)")
            }
        }
    }
    
    func configureGroupSession(_ groupSession: GroupSession<DrawTogether>) {
        reset()
        self.groupSession = groupSession

        
        let messenger = GroupSessionMessenger(session: groupSession)
        self.messenger = messenger
        

        groupSession.$activeParticipants
            .sink { activeParticipants in
                let newParticipants =
                activeParticipants.subtracting(groupSession.activeParticipants)
                Task {
                    do {
                        try await messenger.send(CanvasMessage(strokes: self.strokes,
                                                            pointCount: self.pointCount),
                                                  to: .only(newParticipants))
                    }  catch {}
                }
            }
            .store(in: &subscriptions)
        
        
        
        
        let strokeTask = Task.detached { [weak self] in
            for await (message, _) in messenger.messages(of:UpsertStrokeMessage.self)  {
                await self?.handle(message)
            }
        }
        tasks.insert(strokeTask)
        groupSession.join()
        
        _ = Task.detached { [weak self] in
            for await (message, _) in messenger.messages(of: CanvasMessage.self) {
                await self?.handle(message)
            }
        }
        
        
        
    }
    
        
     
        
//        groupSession.$state
//            .sink { state in
//                if case .invalidated = state {
//                    self.groupSession = nil
//                    self.reset()
//                }
//            }
//            .store(in: &subscriptions)
//

//
//        var task = Task {
//            for await (message, _) in messenger.messages(of: UpsertStrokeMessage.self) {
//                handle(message)
//            }
//        }
//        tasks.insert(task)
//
//        task = Task {
//            for await (message, _) in messenger.messages(of: CanvasMessage.self) {
//                handle(message)
//            }
//        }
//        tasks.insert(task)

    

    func handle(_ message: UpsertStrokeMessage) {
        if let stroke = strokes.first(where: { $0.id == message.id }) {
            stroke.points.append(message.point)
        } else {
            let stroke = Stroke(id: message.id, color: message.color)
            stroke.points.append(message.point)
            strokes.append(stroke)
        }
    }

    func handle(_ message: CanvasMessage) {
        guard message.pointCount > self.pointCount else { return }
        self.strokes = message.strokes
    }
}
