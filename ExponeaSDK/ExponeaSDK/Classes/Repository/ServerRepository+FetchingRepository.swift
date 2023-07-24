//
//  ServerRepository+FetchingRepository.swift
//  ExponeaSDK
//
//  Created by Panaxeo on 05/03/2020.
//  Copyright © 2020 Exponea. All rights reserved.
//

import Foundation

extension ServerRepository: FetchRepository {
    func fetchRecommendation<T: RecommendationUserData>(
        request: RecommendationRequest,
        for customerIds: [String: String],
        completion: @escaping (Result<RecommendationResponse<T>>) -> Void
    ) {
        let router = RequestFactory(exponeaProject: configuration.mainProject, route: .customerAttributes)
        let request = router.prepareRequest(parameters: request, customerIds: customerIds)

        session
            .dataTask(
                with: request,
                completionHandler: router.handler(
                    with: { (result: Result<WrappedRecommendationResponse<T>>) in
                        if let response = result.value {
                            // response is wrapped into an array of results for requests.
                            // we only sent one request, so we only care about first result
                            if response.success, response.results.count > 0 {
                                completion(Result.success(response.results[0]))
                            } else {
                                completion(Result.failure(RepositoryError.serverError(nil)))
                            }
                        } else {
                            completion(Result.failure(result.error ?? RepositoryError.serverError(nil)))
                        }
                    }
                )
            )
            .resume()
    }

    /// Fetch the list of your existing consent categories.
    ///
    /// - Parameter completion: A closure executed upon request completion containing the result
    ///                         which has either the returned data or error.
    func fetchConsents(completion: @escaping (Result<ConsentsResponse>) -> Void) {
        let router = RequestFactory(exponeaProject: configuration.mainProject, route: .consents)
        let request = router.prepareRequest()
        session
            .dataTask(with: request, completionHandler: router.handler(with: completion))
            .resume()
    }

    func fetchInAppMessages(
        for customerIds: [String: String],
        completion: @escaping (Result<InAppMessagesResponse>) -> Void
    ) {
        let router = RequestFactory(exponeaProject: configuration.mainProject, route: .inAppMessages)
        let request = router.prepareRequest(parameters: InAppMessagesRequest(), customerIds: customerIds)
        session
            .dataTask(with: request, completionHandler: router.handler(with: completion))
            .resume()
    }
    
    func fetchAppInbox(
        for customerIds: [String: String],
        with syncToken: String?,
        completion: @escaping (Result<AppInboxResponse>) -> Void
    ) {
        let router = RequestFactory(exponeaProject: configuration.mutualExponeaProject, route: .appInbox)
        let request = router.prepareRequest(
            parameters: AppInboxRequest(syncToken: syncToken),
            customerIds: customerIds
        )
        session
            .dataTask(with: request, completionHandler: router.handler(with: completion))
            .resume()
    }

    func postReadFlagAppInbox(
        on messageIds: [String],
        for customerIds: [String: String],
        with syncToken: String,
        completion: @escaping (EmptyResult<RepositoryError>) -> Void
    ) {
        let router = RequestFactory(exponeaProject: configuration.mutualExponeaProject, route: .appInboxMarkRead)
        let request = router.prepareRequest(
            parameters: AppInboxMarkReadRequest(messageIds: messageIds, syncToken: syncToken),
            customerIds: customerIds
        )
        session
            .dataTask(with: request, completionHandler: router.handler(with: completion))
            .resume()
    }

    func getInlineMessages(
        completion: @escaping TypeBlock<Result<InlineMessageDataResponse>>
    ) {
        let router = RequestFactory(exponeaProject: configuration.mutualExponeaProject, route: .inlineMessages)
        let request = router.prepareRequest()
        session
            .dataTask(with: request, completionHandler: router.handler(with: completion))
            .resume()
    }
    
    func personalizedInlineMessages(
        customerIds: [String: String],
        inlineMessageIds: [String],
        completion: @escaping (Result<PersonalizedInlineMessageResponseData>) -> Void
    ) {
        let router = RequestFactory(exponeaProject: configuration.mutualExponeaProject, route: .personalizedInlineMessages)
        let request = router.prepareRequest(
            parameters: InlineMessageRequest(messageIds: inlineMessageIds),
            customerIds: customerIds
        )
        session
            .dataTask(with: request, completionHandler: router.handler(with: completion))
            .resume()
    }
}
