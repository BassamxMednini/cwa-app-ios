//
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
//

import UIKit
import Combine

final class ExposureSubmissionWarnEuropeConsentViewController: DynamicTableViewController, ENANavigationControllerWithFooterChild {

	typealias PrimaryButtonHandler = (Bool, @escaping (Bool) -> Void) -> Void

	// MARK: - Init

	init?(
		coder: NSCoder,
		onPrimaryButtonTap: @escaping PrimaryButtonHandler
	) {
		self.onPrimaryButtonTap = onPrimaryButtonTap

		super.init(coder: coder)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - Overrides

	override func viewDidLoad() {
		super.viewDidLoad()

		setupView()
	}

	// MARK: - Protocol ENANavigationControllerWithFooterChild

	func navigationController(_ navigationController: ENANavigationControllerWithFooter, didTapPrimaryButton button: UIButton) {
		onPrimaryButtonTap(consentGiven) { [weak self] isLoading in
		   self?.navigationFooterItem?.isPrimaryButtonLoading = isLoading
		   self?.navigationFooterItem?.isPrimaryButtonEnabled = !isLoading
		}
	}

	// MARK: - Private

	private let onPrimaryButtonTap: PrimaryButtonHandler

	@Published var consentGiven: Bool = false
	private var consentSubscription: AnyCancellable?

	private func setupView() {
		navigationItem.title = AppStrings.ExposureSubmissionWarnEuropeConsent.title
		navigationFooterItem?.primaryButtonTitle = AppStrings.ExposureSubmissionWarnEuropeConsent.continueButton

		setupTableView()
	}

	private func setupTableView() {
		tableView.delegate = self
		tableView.dataSource = self

		tableView.register(
			DynamicTableViewRoundedCell.self,
			forCellReuseIdentifier: CustomCellReuseIdentifiers.roundedCell.rawValue
		)

		dynamicTableViewModel = dynamicTableViewModel()
	}

	private func dynamicTableViewModel() -> DynamicTableViewModel {
		DynamicTableViewModel.with {
			$0.add(
				.section(
					header: .image(
						UIImage(named: "Illu_Submission_EuropaweitWarnen"),
						accessibilityLabel: AppStrings.ExposureSubmissionWarnEuropeConsent.imageDescription,
						accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionWarnEuropeConsent.imageDescription,
						height: 250
					),
					cells: [
						.title2(
							text: AppStrings.ExposureSubmissionWarnEuropeConsent.sectionTitle,
							accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionWarnEuropeConsent.sectionTitle
						)
					]
				)
			)
			$0.add(
				.section(
					header: .space(height: 20),
					footer: .space(height: 20),
					separators: true,
					cells: [
						.icon(
							UIImage(named: "flag.eu"),
							text: AppStrings.ExposureSubmissionWarnEuropeConsent.toggleTitle,
							iconWidth: 28,
							action: .execute { [weak self] _ in
								self?.consentGiven.toggle()
							},
							configure: { [weak self] _, cell, _ in
								guard let self = self, let cell = cell as? DynamicTableViewIconCell else { return }

								let consentSwitch = UISwitch()
								consentSwitch.isOn = self.consentGiven
								consentSwitch.accessibilityIdentifier = AccessibilityIdentifiers.ExposureSubmissionWarnEuropeConsent.consentSwitch
								cell.accessoryView = consentSwitch

								consentSwitch.addTarget(self, action: #selector(self.switchToggled(_:)), for: .valueChanged)

								self.consentSubscription = self.$consentGiven.sink { consentGiven in
									// .receive(on: RunLoop.main) would delay the setting after scrolling is finished, that's why DispatchQueue.main.async is used in this case
									DispatchQueue.main.async {
										consentSwitch.setOn(consentGiven, animated: true)
									}
								}
							}
						)
					]
				)
			)
			$0.add(
				.section(
					cells: [
						.body(
							text: AppStrings.ExposureSubmissionWarnEuropeConsent.description,
							accessibilityIdentifier: nil
						),
						.custom(
							withIdentifier: CustomCellReuseIdentifiers.roundedCell,
							configure: { _, cell, _ in
								guard let cell = cell as? DynamicTableViewRoundedCell else { return }

								cell.configure(
									title: NSMutableAttributedString(
										string: AppStrings.ExposureSubmissionWarnEuropeConsent.consentTitle
									),
									body: NSMutableAttributedString(
										string: AppStrings.ExposureSubmissionWarnEuropeConsent.consentDescription
									),
									textStyle: .textPrimary1,
									backgroundStyle: .separator
								)
							}
						)
					]
				)
			)
		}
	}

	@objc
	func switchToggled(_ sender: UISwitch) {
		self.consentGiven = sender.isOn
	}

}

// MARK: - Cell reuse identifiers.

extension ExposureSubmissionWarnEuropeConsentViewController {
	enum CustomCellReuseIdentifiers: String, TableViewCellReuseIdentifiers {
		case roundedCell
	}
}
