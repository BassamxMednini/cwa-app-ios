// Corona-Warn-App
//
// SAP SE and all other contributors
// copyright owners license this file to you under the Apache
// License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import BackgroundTasks
import ExposureNotification
import UIKit

enum ENATaskIdentifier: String, CaseIterable {
	// only one task identifier is allowed have the .exposure-notification suffix
	case exposureNotification = "exposure-notification"
	case fetchTestResults = "fetch-test-results"

	var backgroundTaskScheduleInterval: TimeInterval? {
		switch self {
		case .exposureNotification: return nil
		case .fetchTestResults: return 2 * 60 * 60
		}
	}
	var backgroundTaskSchedulerIdentifier: String {
		guard let bundleID = Bundle.main.bundleIdentifier else { return "invalid-task-id!" }
		return "\(bundleID).\(rawValue)"
	}
}

protocol ENATaskExecutionDelegate: AnyObject {
	func executeExposureDetectionRequest(task: BGTask, completion: @escaping ((Bool) -> Void))
	func executeFetchTestResults(task: BGTask, completion: @escaping ((Bool) -> Void))
}

final class ENATaskScheduler {
	static let shared = ENATaskScheduler()

	private init() {
		registerTasks()
	}

	weak var taskDelegate: ENATaskExecutionDelegate?

	typealias CompletionHandler = (() -> Void)

	private func registerTasks() {
		registerTask(with: .exposureNotification, taskHandler: executeExposureDetectionRequest(_:))
		registerTask(with: .fetchTestResults, taskHandler: executeFetchTestResults(_:))
	}

	private func registerTask(with taskIdentifier: ENATaskIdentifier, taskHandler: @escaping ((BGTask) -> Void)) {
		let identifierString = taskIdentifier.backgroundTaskSchedulerIdentifier
		BGTaskScheduler.shared.register(forTaskWithIdentifier: identifierString, using: .main) { task in
			taskHandler(task)
			task.expirationHandler = {
				task.setTaskCompleted(success: false)
			}
		}

		// Add in local notifications for debugging.
		showNotification(
			title: "registerTask() called.",
			subtitle: "\(Date())",
			body: "Task identifier: \(identifierString)",
			notificationIdentifier: "registerTask(taskIdentifier: \(identifierString)"
		)

	}

	func scheduleTasks() {
		scheduleTask(for: .exposureNotification, cancelExisting: true)
		scheduleTask(for: .fetchTestResults, cancelExisting: true)
	}

	func cancelTasks() {
		BGTaskScheduler.shared.cancelAllTaskRequests()
	}

	func scheduleTask(for identifier: String) {
		guard let taskIdentifier = ENATaskIdentifier(rawValue: identifier) else { return }
		scheduleTask(for: taskIdentifier)
	}

	func scheduleTask(for taskIdentifier: ENATaskIdentifier, cancelExisting: Bool = false) {

		if cancelExisting {
			cancelTask(for: taskIdentifier)
		}

		let taskRequest = BGProcessingTaskRequest(identifier: taskIdentifier.backgroundTaskSchedulerIdentifier)
		taskRequest.requiresNetworkConnectivity = true
		taskRequest.requiresExternalPower = false
		if let interval = taskIdentifier.backgroundTaskScheduleInterval {
			taskRequest.earliestBeginDate = Date(timeIntervalSinceNow: interval)
		} else {
			taskRequest.earliestBeginDate = nil
		}

		do {
			try BGTaskScheduler.shared.submit(taskRequest)
		} catch {
			logError(message: error.localizedDescription)
		}

	}

	func cancelTask(for taskIdentifier: ENATaskIdentifier) {
		BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier.backgroundTaskSchedulerIdentifier)
	}

	// Task Handlers:
	private func executeExposureDetectionRequest(_ task: BGTask) {

		// Add in local notifications for debugging.
		showNotification(
			title: "executeExposureDetectionRequest() called.",
			subtitle: "\(Date())",
			body: "Task identifier: \(task.identifier)",
			notificationIdentifier: task.identifier
		)

		taskDelegate?.executeExposureDetectionRequest(task: task) { success in
			task.setTaskCompleted(success: success)
		}
		scheduleTask(for: task.identifier)
	}

	private func executeFetchTestResults(_ task: BGTask) {

		// Add in local notifications for debugging.
		showNotification(
			title: "executeFetchTestResults() called.",
			subtitle: "\(Date())",
			body: "Task identifier: \(task.identifier)",
			notificationIdentifier: task.identifier
		)

		taskDelegate?.executeFetchTestResults(task: task) { success in
			task.setTaskCompleted(success: success)
		}
		scheduleTask(for: task.identifier)
	}

	private func showNotification(
		title: String,
		subtitle: String,
		body: String,
		notificationIdentifier: String
	) {

		let content = UNMutableNotificationContent()
		content.title = title
		content.subtitle = subtitle
		content.body = body

		let trigger = UNTimeIntervalNotificationTrigger(
			timeInterval: 1,
			repeats: false
		)

		let request = UNNotificationRequest(
			identifier: notificationIdentifier,
			content: content,
			trigger: trigger
		)

		UNUserNotificationCenter.current().add(request) { error in
			guard let error = error else { return }
			logError(message: "There was an error scheduling the local notification. \(error.localizedDescription)")
		}
	}

}

extension ENATaskScheduler: ExposureStateUpdating {
	func updateExposureState(_ state: ExposureManagerState) {
		if state.isGood {
			scheduleTasks()
		} else {
			cancelTasks()
		}
	}
}
