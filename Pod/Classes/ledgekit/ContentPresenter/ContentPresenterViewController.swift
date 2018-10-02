//
//  ContentPresenterViewController.swift
//  ShiftSDK
//
//  Created by Takeichi Kanzaki on 17/09/2018.
//
//

import UIKit
import SnapKit
import TTTAttributedLabel
import Bond
import ReactiveKit

class ContentPresenterViewController: ShiftViewController {
  private unowned let presenter: ContentPresenterPresenterProtocol
  private let webView = UIWebView()
  private let textView = TTTAttributedLabel(frame: CGRect.zero)

  init(uiConfiguration: ShiftUIConfig, presenter: ContentPresenterPresenterProtocol) {
    self.presenter = presenter
    super.init(uiConfiguration: uiConfiguration)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    setUpUI()
    setupViewModelSubscriptions()
    presenter.viewLoaded()
  }

  override func closeTapped() {
    presenter.closeTapped()
  }
}

// MARK: - Show content
private extension ContentPresenterViewController {
  func setupViewModelSubscriptions() {
    _ = presenter.viewModel.content.ignoreNil().observeNext { content in
      self.set(content: content)
    }
  }

  func set(content: Content) {
    switch content {
    case .plainText, .markdown:
      guard let attributedString = content.attributedString(font: uiConfiguration.instructionsFont,
                                                            color: uiConfiguration.textPrimaryColor,
                                                            linkColor: uiConfiguration.uiPrimaryColor) else {
        showEmptyContent()
        return
      }
      show(attributedString)
    case .externalURL(let url):
      show(url)
    }
  }

  func showEmptyContent() {
    fatalError("The content can't be shown.")
  }

  func show(_ url: URL) {
    showLoadingSpinner(tintColor: uiConfiguration.uiPrimaryColor)
    let request = NSMutableURLRequest(url: url)
    webView.loadRequest(request as URLRequest)
    webView.isHidden = false
    textView.isHidden = true
  }

  func show(_ attributedString: NSAttributedString) {
    textView.attributedText = attributedString
    webView.isHidden = true
    textView.isHidden = false
  }
}

// MARK: - Setup UI
private extension ContentPresenterViewController {
  func setUpUI() {
    view.backgroundColor = uiConfiguration.backgroundColor
    setUpNavigationBar()
    setUpTextView()
    setUpWebView()
  }

  func setUpNavigationBar() {
    navigationController?.navigationBar.setUpWith(uiConfig: uiConfiguration)
    showNavCancelButton(uiConfiguration.iconTertiaryColor)
  }

  func setUpTextView() {
    view.addSubview(textView)
    textView.linkAttributes = [NSAttributedStringKey.foregroundColor: uiConfiguration.textPrimaryColor,
                               kCTUnderlineStyleAttributeName as AnyHashable: false]
    textView.enabledTextCheckingTypes = NSTextCheckingAllTypes
    textView.delegate = self
    textView.numberOfLines = 0
    textView.verticalAlignment = .top
    textView.snp.makeConstraints { make in
      make.margins.equalToSuperview().inset(16)
    }
    textView.isHidden = true
  }

  func setUpWebView() {
    webView.isHidden = true
    view.addSubview(webView)
    webView.snp.makeConstraints { make in
      make.margins.equalToSuperview()
    }
    webView.delegate = self
  }
}

extension ContentPresenterViewController: TTTAttributedLabelDelegate {
  //swiftlint:disable:next implicitly_unwrapped_optional
  func attributedLabel(_ label: TTTAttributedLabel!, didSelectLinkWith url: URL!) {
    presenter.linkTapped(url)
  }
}

extension ContentPresenterViewController: UIWebViewDelegate {
  func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
    hideLoadingSpinner()
    show(error: error)
  }

  func webViewDidFinishLoad(_ webView: UIWebView) {
    hideLoadingSpinner()
  }
}