//
//  ContentView.swift
//  FormValidationDemo
//
//  Created by Vinicius Maino on 31/01/21.
//

import SwiftUI
import Combine

//Model

enum PasswordStatus {
    case empty
    case notStrongEnough
    case repeatedPasswordWrong
    case valid
}

//ViewModel

class FormViewModel: ObservableObject {
    
    @Published var username = ""
    @Published var password = ""
    @Published var passwordAgain = ""
    
    @Published var inlineErrorForPassword = ""
    
    @Published var isValid = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private static let predicate = NSPredicate(format: "SELF MATCHES %@", "^(?=.*[a-z])(?=.*[$@$#!%*?&]).{6,}$")
    
    private var isUsernameValidPublisher: AnyPublisher<Bool, Never> {
        $username
            .debounce(for: 0.8, scheduler: RunLoop.main)
            .removeDuplicates()
            .map { $0.count >= 3 }
            .eraseToAnyPublisher()
    }
    
    private var isPasswordEmptyPublisher: AnyPublisher<Bool, Never> {
        $password
            .debounce(for: 0.8, scheduler: RunLoop.main)
            .removeDuplicates()
            .map { $0.isEmpty }
            .eraseToAnyPublisher()
    }
    
    private var arePasswordsEqualPublisher: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest($password, $passwordAgain)
            .debounce(for: 0.2, scheduler: RunLoop.main)
            .map { $0 == $1 }
            .eraseToAnyPublisher()
    }
    
    private var isPasswordStrongPublisher: AnyPublisher<Bool, Never> {
        $password
            .debounce(for: 0.2, scheduler: RunLoop.main)
            .removeDuplicates()
            .map { Self.predicate.evaluate(with: $0) }
            .eraseToAnyPublisher()
    }
    
    private var isPasswordValidPubisher: AnyPublisher<PasswordStatus, Never> {
        Publishers.CombineLatest3(isPasswordEmptyPublisher, isPasswordStrongPublisher, arePasswordsEqualPublisher)
            .map {
                if $0 { return PasswordStatus.empty }
                if !$1 { return PasswordStatus.notStrongEnough }
                if !$2 { return PasswordStatus.repeatedPasswordWrong }
                return PasswordStatus.valid
            }
            .eraseToAnyPublisher()
    }
    
    private var isFormValidPublisher: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest(isPasswordValidPubisher, isUsernameValidPublisher)
            .map { $0 == .valid && $1}
            .eraseToAnyPublisher()
    }
    
    init() {
        isFormValidPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.isValid, on: self)
            .store(in: &cancellables)
        
        isPasswordValidPubisher
            .dropFirst()
            .receive(on: RunLoop.main)
            .map {
                passwordStatus in
                switch passwordStatus {
                case .empty:
                    return "Password cannot be empty!"
                case .notStrongEnough:
                    return "Password is too weak!"
                case .repeatedPasswordWrong:
                    return "Passwords do not match!"
                case .valid:
                    return ""
                }
            }
            .assign(to: \.inlineErrorForPassword, on: self)
            .store(in: &cancellables)
    }
    
}


//View

struct ContentView: View {
    
    @StateObject private var formViewModel = FormViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("USERNAME")) {
                        TextField("Username", text: $formViewModel.username)
                            .autocapitalization(.none)
                    }
                    
                    Section(header: Text("PASSWORD"), footer: Text(formViewModel.inlineErrorForPassword).foregroundColor(.red)) {
                        TextField("Password", text: $formViewModel.password)
                            .autocapitalization(.none)
                            
                        TextField("Password Again", text: $formViewModel.passwordAgain)
                            .autocapitalization(.none)
                    }
                }
                
                Button(action: {}) {
                    RoundedRectangle(cornerRadius: 10)
                        .frame(height: 60)
                        .overlay(
                            Text("Continue")
                                .foregroundColor(.white)
                        )
                }
                .padding()
                .disabled(!formViewModel.isValid)
            }
            .navigationTitle("Sign Up")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
