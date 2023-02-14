//
//  AppInboxTrackingSpec.swift
//  ExponeaSDKTests
//
//  Created by Adam Mihalik on 23/01/2023.
//  Copyright © 2023 Exponea. All rights reserved.
//

import Foundation
import Nimble
import Mockingjay
import Quick

@testable import ExponeaSDK
@testable import ExponeaSDKShared

final class AppInboxTrackingSpec: QuickSpec {

    let configuration = try! Configuration(
        projectToken: "token",
        authorization: Authorization.none,
        baseUrl: "baseUrl"
    )

    override func spec() {
        var trackingManager: TrackingManagerType!
        var trackingConsentManager: TrackingConsentManagerType!
        var appInboxManager: AppInboxManager!
        var repository: MockRepository!
        var database: MockDatabaseManager!
        var flushManager: MockFlushingManager!

        describe("AppInbox tracking") {
            beforeEach {
                repository = MockRepository(configuration: self.configuration)
                flushManager = MockFlushingManager()
                database = try! MockDatabaseManager()
                trackingManager = try! TrackingManager(
                    repository: repository,
                    database: database,
                    flushingManager: flushManager,
                    userDefaults: UserDefaults(),
                    onEventCallback: { _, _ in
                        // nothing
                    })
                appInboxManager = AppInboxManager(
                    repository: repository,
                    trackingManager: trackingManager,
                    database: database
                )
                AppInboxCache().clear()
                trackingConsentManager = TrackingConsentManager(trackingManager: trackingManager)
            }

            it("should track opened AppInbox") {
                let customerIds = try identifyCustomer(["registered": "test@example.com"]).ids
                let testMessage = try fetchTestMessage(id: "id1", syncToken: "sync123")
                trackingConsentManager.trackAppInboxOpened(message: testMessage, mode: .IGNORE_CONSENT)
                let trackedEvents = try fetchTrackEvents()
                expect(trackedEvents.count).to(equal(1))
                expect(trackedEvents.first?.eventType).to(equal("campaign"))
                expect(trackedEvents.first?.customerIds).to(equal(customerIds))
            }

            it("should track clicked AppInbox") {
                let customerIds = try identifyCustomer(["registered": "test@example.com"]).ids
                let testMessage = try fetchTestMessage(id: "id1", syncToken: "sync123")
                let actionText = "ACTION"
                let actionUrl = "https://example.com"
                trackingConsentManager.trackAppInboxClick(
                    message: testMessage,
                    buttonText: actionText,
                    buttonLink: actionUrl,
                    mode: .IGNORE_CONSENT
                )
                let trackedEvents = try fetchTrackEvents()
                expect(trackedEvents.count).to(equal(1))
                expect(trackedEvents.first?.eventType).to(equal("campaign"))
                expect(trackedEvents.first?.customerIds).to(equal(customerIds))
                expect(trackedEvents.first?.dataTypes.properties["cta"] as? String).to(equal(actionText))
                expect(trackedEvents.first?.dataTypes.properties["url"] as? String).to(equal(actionUrl))
            }

            it("should NOT track opened Message without assignment") {
                let customerIds = try identifyCustomer(["registered": "test@example.com"]).ids
                var testMessage = try fetchTestMessage(id: "id1", syncToken: "sync123")
                testMessage.customerId = nil    // unassign from customer
                trackingConsentManager.trackAppInboxOpened(message: testMessage, mode: .IGNORE_CONSENT)
                let trackedEvents = try fetchTrackEvents()
                expect(trackedEvents.count).to(equal(0))
            }

            it("should NOT track clicked AppInbox") {
                let customerIds = try identifyCustomer(["registered": "test@example.com"]).ids
                var testMessage = try fetchTestMessage(id: "id1", syncToken: "sync123")
                testMessage.customerId = nil
                let actionText = "ACTION"
                let actionUrl = "https://example.com"
                trackingConsentManager.trackAppInboxClick(
                    message: testMessage,
                    buttonText: actionText,
                    buttonLink: actionUrl,
                    mode: .IGNORE_CONSENT
                )
                let trackedEvents = try fetchTrackEvents()
                expect(trackedEvents.count).to(equal(0))
            }

            it("should track opened AppInbox for original Customer") {
                let customerIds1 = try identifyCustomer(["registered": "test@example.com"]).ids
                let testMessage1 = try fetchTestMessage(id: "id1", syncToken: "sync123")
                database.makeNewCustomer()
                let customerIds2 = try identifyCustomer(["registered": "another@example.com"]).ids
                let testMessage2 = try fetchTestMessage(id: "id1", syncToken: "sync1234")
                expect(customerIds1).toNot(equal(customerIds2))
                expect(testMessage1.customerId).toNot(equal(testMessage2.customerId))
                trackingConsentManager.trackAppInboxOpened(message: testMessage1, mode: .IGNORE_CONSENT)
                let trackedEvents = try fetchTrackEvents()
                expect(trackedEvents.count).to(equal(1))
                expect(trackedEvents.first?.eventType).to(equal("campaign"))
                expect(trackedEvents.first?.customerIds).to(equal(customerIds1))
            }

            it("should track clicked AppInbox for original Customer") {
                let customerIds1 = try identifyCustomer(["registered": "test@example.com"]).ids
                let testMessage1 = try fetchTestMessage(id: "id1", syncToken: "sync123")
                database.makeNewCustomer()
                let customerIds2 = try identifyCustomer(["registered": "another@example.com"]).ids
                let testMessage2 = try fetchTestMessage(id: "id1", syncToken: "sync1234")
                expect(customerIds1).toNot(equal(customerIds2))
                expect(testMessage1.customerId).toNot(equal(testMessage2.customerId))
                let actionText = "ACTION"
                let actionUrl = "https://example.com"
                trackingConsentManager.trackAppInboxClick(
                    message: testMessage1,
                    buttonText: actionText,
                    buttonLink: actionUrl,
                    mode: .IGNORE_CONSENT
                )
                let trackedEvents = try fetchTrackEvents()
                expect(trackedEvents.count).to(equal(1))
                expect(trackedEvents.first?.eventType).to(equal("campaign"))
                expect(trackedEvents.first?.customerIds).to(equal(customerIds1))
                expect(trackedEvents.first?.dataTypes.properties["cta"] as? String).to(equal(actionText))
                expect(trackedEvents.first?.dataTypes.properties["url"] as? String).to(equal(actionUrl))
            }
        }

        func identifyCustomer(_ ids: [String: String]) throws -> CustomerThreadSafe {
            try database.identifyCustomer(with: [.customerIds(ids)], into: self.configuration.mainProject)
            return database.currentCustomer
        }

        func fetchTrackEvents() throws -> [TrackEventProxy] {
            try database.fetchTrackEvent().filter({ event in
                // exclude common and expected events
                ["installation", "session_start", "session_end"].firstIndex(of: event.eventType) == nil
            })
        }

        /// Creates a test message and goes through 'fetch process' to gain syncToken and customerId to be usable for next handling
        func fetchTestMessage(id: String, syncToken: String?) throws -> MessageItem {
            let response = AppInboxResponse(
                success: true,
                messages: [
                    AppInboxCacheSpec.getSampleMessage(id: "id1")
                ],
                syncToken: syncToken
            )
            repository.fetchAppInboxResult = Result.success(response)
            var fetchedMessage: MessageItem?
            waitUntil(timeout: .seconds(30)) { done in
                appInboxManager.fetchAppInbox { result in
                    fetchedMessage = result.value?.first
                    done()
                }
            }
            enum MyError: Error {
                case someError(message: String)
            }
            guard let fetchedMessage = fetchedMessage else {
                // this MAY happen only if AppInboxManagerSpec are failing
                // or AppInboxManager changed but tests are missing
                throw MyError.someError(message: "check AppInbox fetch tests")
            }
            return fetchedMessage
        }
    }
}
