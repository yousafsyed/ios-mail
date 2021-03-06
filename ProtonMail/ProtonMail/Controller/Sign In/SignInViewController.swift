//
//  SignInViewController.swift
//  ProtonMail
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonMail.
//
//  ProtonMail is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonMail is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonMail.  If not, see <https://www.gnu.org/licenses/>.


import UIKit
import MBProgressHUD
import DeviceCheck
import PromiseKit

class SignInViewController: ProtonMailViewController {
    static var isComeBackFromMailbox = false
    
    private let animationDuration: TimeInterval = 0.5
    private let keyboardPadding: CGFloat        = 12
    private let buttonDisabledAlpha: CGFloat    = 0.5
    
    private let kDecryptMailboxSegue            = "mailboxSegue"
    private let kSignUpKeySegue                 = "sign_in_to_sign_up_segue"
    private let kSegueToSignUpWithNoAnimation   = "sign_in_to_splash_no_segue"
    private let kSegueToPinCodeViewNoAnimation  = "pin_code_segue"
    private let kSegueToBioViewNoAnimation      = "bio_code_segue"
    private let kSegueTo2FACodeSegue            = "2fa_code_segue"
    
    private var isShowpwd      = false
    private var isRemembered   = false
    
    //define
    private let hidePriority : UILayoutPriority = UILayoutPriority(rawValue: 1.0)
    private let showPriority: UILayoutPriority  = UILayoutPriority(rawValue: 750.0)
    
    //views
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var usernameView: UIView!
    @IBOutlet weak var passwordView: UIView!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var onePasswordButton: UIButton!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var signInTitle: UILabel!
    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var forgotPwdButton: UIButton!
    @IBOutlet weak var languagesLabel: UILabel!
    
    // Constraints
    @IBOutlet weak var userLeftPaddingConstraint: NSLayoutConstraint!
    @IBOutlet weak var userTopPaddingConstraint: NSLayoutConstraint!
    @IBOutlet weak var logoLeftPaddingConstraint: NSLayoutConstraint!
    @IBOutlet weak var logoTopPaddingConstraint: NSLayoutConstraint!
    @IBOutlet weak var userNameTopPaddingConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollBottomPaddingConstraint: NSLayoutConstraint!
    @IBOutlet weak var loginMidlineConstraint: NSLayoutConstraint!
    @IBOutlet weak var loginWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var signUpTopConstraint: NSLayoutConstraint!
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTextFields()
        setupButtons()
        setupVersionLabel()
    }
    
    @IBAction func changeLanguagesAction(_ sender: UIButton) {
        if #available(iOS 13.0, *) {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        } else {
            let current_language = LanguageManager.currentLanguageEnum()
            let title = LocalString._settings_current_language_is + current_language.nativeDescription
            let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction(title: LocalString._general_cancel_button, style: .cancel, handler: nil))
            for l in ELanguage.allItems() {
                if l != current_language {
                    alertController.addAction(UIAlertAction(title: l.nativeDescription, style: .default, handler: { (action) -> Void in
                        let _ = self.navigationController?.popViewController(animated: true)
                        LanguageManager.saveLanguage(byCode: l.code)
                        LocalizedString.reset()
                        UIView.animate(withDuration: 0.25, delay: 0, options: UIView.AnimationOptions(), animations: { () -> Void in
                            self.setupTextFields()
                            self.setupButtons()
                            self.setupVersionLabel()
                            self.view.layoutIfNeeded()
                        }, completion: nil)

                    }))
                }
            }
            
            alertController.popoverPresentationController?.sourceView = sender
            alertController.popoverPresentationController?.sourceRect = sender.bounds
            present(alertController, animated: true, completion: nil)
        }
    }
    
    internal func setupVersionLabel () {
        let language: ELanguage =  LanguageManager.currentLanguageEnum()
        languagesLabel.text = language.nativeDescription
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                versionLabel.text = "v" + version + "(\(build))"
            } else {
                versionLabel.text = "v" + version
            }
        } else {
            versionLabel.text = ""
        }
    }
    
    func setupView() {
        if isRemembered {
            hideLoginViews()
        } else {
            showLoginViews()
            if !userCachedStatus.isSplashOk() {
                self.performSegue(withIdentifier: kSegueToSignUpWithNoAnimation, sender: self)
            }
        }
    }
    
    override var shouldAutorotate : Bool {
        return false
    }
    
    func configConstraint(_ show : Bool) -> Void {
        let level = show ? showPriority : hidePriority
        
        userLeftPaddingConstraint.priority = level
        userTopPaddingConstraint.priority = level
        logoLeftPaddingConstraint.priority = level
        logoTopPaddingConstraint.priority = level
        
        userNameTopPaddingConstraint.priority = level
    }
    
    @IBAction func showPasswordAction(_ sender: UIButton) {
        isShowpwd = !isShowpwd
        sender.isSelected = isShowpwd
        
        if isShowpwd {
            self.passwordTextField.isSecureTextEntry = false
        } else {
            self.passwordTextField.isSecureTextEntry = true
        }
    }
        
    override func didMove(toParent parent: UIViewController?) {
        if (!(parent?.isEqual(self.parent) ?? false)) {
        }
        
        if SignInViewController.isComeBackFromMailbox {
            showLoginViews()
            SignInManager.shared.clean()
        }
    }
    
    @IBAction func onePasswordAction(_ sender: UIButton) {
        OnePasswordExtension.shared().findLogin(forURLString: "https://protonmail.com",
                                                for: self,
                                                sender: sender,
                                                completion: { (loginDictionary, error) -> Void in
            if loginDictionary == nil {
                if error!._code != Int(AppExtensionErrorCodeCancelledByUser) {
                    PMLog.D("Error invoking Password App Extension for find login: \(String(describing: error))")
                }
                return
            }
            
            let username : String = (loginDictionary?[AppExtensionUsernameKey] as? String ?? "").trim()
            let password : String = (loginDictionary?[AppExtensionPasswordKey] as? String ?? "")
            
            self.usernameTextField.text = username
            self.passwordTextField.text = password
            
            if !username.isEmpty && !password.isEmpty {
                self.updateSignInButton(usernameText: username, passwordText: password)
                self.signIn(username: self.usernameTextField.text ?? "",
                            password: self.passwordTextField.text ?? "",
                            cachedTwoCode: nil) // FIXME
            }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        NotificationCenter.default.addKeyboardObserver(self)
        
        let uName = (usernameTextField.text ?? "").trim()
        let pwd = (passwordTextField.text ?? "")
        
        updateSignInButton(usernameText: uName, passwordText: pwd)
        
        if OnePasswordExtension.shared().isAppExtensionAvailable() == true {
            onePasswordButton.isHidden = false
            loginWidthConstraint.constant = 120
            loginMidlineConstraint.constant = -72
        } else {
            onePasswordButton.isHidden = true
            loginWidthConstraint.constant = 200
            loginMidlineConstraint.constant = 0
        }
        
        // choose flow
        
        if sharedUserDataService.isNewUser {
            sharedUserDataService.isNewUser = false
            /// This logic is when creating new user success but the setup key is failed.
            /// when creating user success the isUserCredentialStored will be true but isTouchIDEnabled and isPinCodeEnabled should be all false
            /// this also fixed the user see the mailbox password view after created the new account and enable the pin/face in the same session.
            if sharedUserDataService.isUserCredentialStored && !userCachedStatus.isTouchIDEnabled && !userCachedStatus.isPinCodeEnabled {
                UnlockManager.shared.unlockIfRememberedCredentials(requestMailboxPassword: {
                    self.isRemembered = true
                    self.performSegue(withIdentifier: self.kDecryptMailboxSegue, sender: self)
                })
                if isRemembered {
                    hideLoginViews()
                } else {
                    showLoginViews()
                }
            }
        }
        
        // unlock when locked
        
        let signinFlow = UnlockManager.shared.getUnlockFlow()
        switch signinFlow {
        case .requirePin:
            self.performSegue(withIdentifier: self.kSegueToPinCodeViewNoAnimation, sender: self)
        case .requireTouchID:
            self.performSegue(withIdentifier: self.kSegueToBioViewNoAnimation, sender: self)
        case .restore:
            /* nothing here, let the user login from the beginning */
            break
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if SignInViewController.isComeBackFromMailbox {
            showLoginViews()
            SignInManager.shared.clean()
        }
        
        if UIDevice.current.isLargeScreen() && !isRemembered {
            usernameTextField.becomeFirstResponder()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeKeyboardObserver(self)
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == kSignUpKeySegue {
            let viewController = segue.destination as! SignUpUserNameViewController
            let deviceCheckToken = sender as? String ?? ""
            viewController.viewModel = SignupViewModelImpl(token: deviceCheckToken)
        } else if segue.identifier == kSegueToPinCodeViewNoAnimation {
            let viewController = segue.destination as! PinCodeViewController
            viewController.viewModel = UnlockPinCodeModelImpl()
            viewController.delegate = self
        } else if segue.identifier == kSegueToBioViewNoAnimation {
            let viewController = segue.destination as! BioCodeViewController
            viewController.delegate = self
        } else if segue.identifier == kSegueTo2FACodeSegue {
            let popup = segue.destination as! TwoFACodeViewController
            popup.delegate = self
            popup.mode = .twoFactorCode
            self.setPresentationStyleForSelfController(self, presentingController: popup)
        }
    }
    
    // MARK: - Private methods
    
    internal func hideLoginViews() {
        self.usernameView.alpha      = 0.0
        self.passwordView.alpha      = 0.0
        self.signInButton.alpha      = 0.0
        self.onePasswordButton.alpha = 0.0
    }
    
    func showLoginViews() {
        UIView.animate(withDuration: 1.0, animations: { () -> Void in
            self.usernameView.alpha      = 1.0
            self.passwordView.alpha      = 1.0
            self.signInButton.alpha      = 1.0
            self.onePasswordButton.alpha = 1.0
        }, completion: { finished in
                        
        })
    }
    
    func dismissKeyboard() {
        usernameTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
    }
    
    internal func setupTextFields() {
        PMLog.D(LocalString._user_login)
        signInTitle.text = LocalString._user_login
        usernameTextField.attributedPlaceholder = NSAttributedString(string: LocalString._username,
                                                                     attributes:[NSAttributedString.Key.foregroundColor : UIColor(hexColorCode: "#cecaca")])
        passwordTextField.attributedPlaceholder = NSAttributedString(string: LocalString._password,
                                                                     attributes:[NSAttributedString.Key.foregroundColor : UIColor(hexColorCode: "#cecaca")])
    }
    
    func setupButtons() {
        signInButton.layer.borderColor      = UIColor.ProtonMail.Login_Button_Border_Color.cgColor
        signInButton.alpha                  = buttonDisabledAlpha
        
        onePasswordButton.layer.borderColor = UIColor.white.cgColor
        onePasswordButton.layer.borderWidth = 2
        
        signInButton.setTitle(LocalString._general_login, for: .normal)
        
        signUpButton.setTitle(LocalString._need_an_account_sign_up, for: .normal)
        forgotPwdButton.setTitle(LocalString._forgot_password, for: .normal)        
    }
    
    func updateSignInButton(usernameText: String, passwordText: String) {
        signInButton.isEnabled = !usernameText.isEmpty && !passwordText.isEmpty
        
        UIView.animate(withDuration: animationDuration, animations: { () -> Void in
            if self.signInButton.alpha != 0.0 {
                self.signInButton.alpha = self.signInButton.isEnabled ? 1.0 : self.buttonDisabledAlpha
            }
        })
    }
    
    // MARK: - Actions
    @IBAction func rememberButtonAction(_ sender: UIButton) {
        isRemembered = !isRemembered
        isRemembered = true
    }
    
    @IBAction func signInAction(_ sender: UIButton) {
        dismissKeyboard()
        self.signIn(username: self.usernameTextField.text ?? "",
                    password: self.passwordTextField.text ?? "",
                    cachedTwoCode: nil) // FIXME
    }
    
    @IBAction func fogorPasswordAction(_ sender: AnyObject) {
        dismissKeyboard()

        let alertStr = LocalString._please_use_the_web_application_to_reset_your_password
        let alertController = alertStr.alertController()
        alertController.addOKAction()
        self.present(alertController, animated: true, completion: nil)
    }
    
    enum TokenError : Error {
        case unsupport
        case empty
        case error
    }
    
    func generateToken() -> Promise<String> {
        if #available(iOS 11.0, *) {
            let currentDevice = DCDevice.current
            if currentDevice.isSupported {
                let deferred = Promise<String>.pending()
                currentDevice.generateToken(completionHandler: { (data, error) in
                    if let tokenData = data {
                        deferred.resolver.fulfill(tokenData.base64EncodedString())
                    } else if let error = error {
                        deferred.resolver.reject(error)
                    } else {
                        deferred.resolver.reject(TokenError.empty)
                    }
                })
                return deferred.promise
            }
        }
        
        #if Enterprise
        return Promise<String>.value("EnterpriseBuildInternalTestOnly".encodeBase64())
        #else
        return Promise<String>.init(error: TokenError.unsupport)
        #endif
    }
    
    @IBAction func signUpAction(_ sender: UIButton) {
        dismissKeyboard()
        firstly {
            generateToken()
        }.done { (token) in
            self.performSegue(withIdentifier: self.kSignUpKeySegue, sender: token)
        }.catch { (error) in
            let alert = LocalString._mobile_signups_are_disabled_pls_later_pm_com.alertController()
            alert.addOKAction()
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func tapAction(_ sender: UITapGestureRecognizer) {
        dismissKeyboard()
    }
    
    internal func signIn(username: String,
                         password: String,
                         cachedTwoCode: String?)
    {
        MBProgressHUD.showAdded(to: self.view, animated: true)
        self.isRemembered = true
        SignInViewController.isComeBackFromMailbox = false
        
        SignInManager.shared.signIn(username: username,
                        password: password,
                        cachedTwoCode: cachedTwoCode,
                        ask2fa: {
                            //2fa
                            MBProgressHUD.hide(for: self.view, animated: true)
                            self.performSegue(withIdentifier: self.kSegueTo2FACodeSegue, sender: self)
        },
                        onError: { error in
                            PMLog.D("error: \(error)")
                            MBProgressHUD.hide(for: self.view, animated: true)
                            self.showLoginViews()
                            if !error.code.forceUpgrade {
                                let alertController = error.alertController()
                                alertController.addOKAction()
                                self.present(alertController, animated: true, completion: nil)
                            }
        },
                        afterSignIn: {
                            MBProgressHUD.hide(for: self.view, animated: true)
        },
                        requestMailboxPassword: {
                            self.isRemembered = true
                            self.performSegue(withIdentifier: self.kDecryptMailboxSegue, sender: self)
        })
    }
}

extension SignInViewController : TwoFACodeViewControllerDelegate {
    func ConfirmedCode(_ code: String, pwd : String) {
        NotificationCenter.default.addKeyboardObserver(self)
        self.signIn(username: self.usernameTextField.text ?? "",
                    password: self.passwordTextField.text ?? "",
                    cachedTwoCode: code)
    }

    func Cancel2FA() {
        sharedUserDataService.twoFactorStatus = 0
        sharedUserDataService.authResponse = nil
        NotificationCenter.default.addKeyboardObserver(self)
    }
}

extension SignInViewController : PinCodeViewControllerDelegate {
    
    func Cancel() {
        UserTempCachedStatus.backup()
        SignInManager.shared.clean()
    }
    
    func Next() {
        UnlockManager.shared.unlockIfRememberedCredentials(requestMailboxPassword: {
            self.isRemembered = true
            self.performSegue(withIdentifier: self.kDecryptMailboxSegue, sender: self)
        })
        setupView()
    }
}

// MARK: - NSNotificationCenterKeyboardObserverProtocol
extension SignInViewController: NSNotificationCenterKeyboardObserverProtocol {
    func keyboardWillHideNotification(_ notification: Notification) {
        let keyboardInfo = notification.keyboardInfo
        scrollBottomPaddingConstraint.constant = 0.0
        self.configConstraint(false)
        UIView.animate(withDuration: keyboardInfo.duration, delay: 0, options: keyboardInfo.animationOption, animations: { () -> Void in
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    func keyboardWillShowNotification(_ notification: Notification) {
        let keyboardInfo = notification.keyboardInfo
        let info: NSDictionary = notification.userInfo! as NSDictionary
        if let keyboardSize = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            scrollBottomPaddingConstraint.constant = keyboardSize.height
        }
        self.configConstraint(true)
        UIView.animate(withDuration: keyboardInfo.duration, delay: 0, options: keyboardInfo.animationOption, animations: { () -> Void in
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}

// MARK: - UITextFieldDelegate
extension SignInViewController: UITextFieldDelegate {
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        updateSignInButton(usernameText: "", passwordText: "")
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let text = textField.text! as NSString
        let changedText = text.replacingCharacters(in: range, with: string)
        
        if textField == usernameTextField {
            updateSignInButton(usernameText: changedText, passwordText: passwordTextField.text!)
        } else if textField == passwordTextField {
            updateSignInButton(usernameText: usernameTextField.text!, passwordText: changedText)
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameTextField {
            passwordTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        
        let uName = (usernameTextField.text ?? "").trim()
        let pwd = (passwordTextField.text ?? "")
        
        if !uName.isEmpty && !pwd.isEmpty {
            self.signIn(username: self.usernameTextField.text ?? "",
                        password: self.passwordTextField.text ?? "",
                        cachedTwoCode: nil) // FIXME
        }
        
        return true
    }
}
