//
//  UserStorage.swift
//  Pods
//
//  Created by Ivan Oliver Martínez on 10/02/16.
//
//

import Foundation
import SwiftyJSON

protocol UserStorageProtocol {
  func createUser(_ developerKey: String,
                  projectKey: String,
                  userData: DataPointList,
                  callback: @escaping Result<ShiftUser, NSError>.Callback)
  func loginWith(_ developerKey: String,
                 projectKey: String,
                 verifications: [Verification],
                 callback: @escaping Result<ShiftUser, NSError>.Callback)
  func getUserData(_ developerKey: String,
                   projectKey: String,
                   userToken: String,
                   availableHousingTypes: [HousingType],
                   availableIncomeTypes: [IncomeType],
                   availableSalaryFrequencies: [SalaryFrequency],
                   filterInvalidTokenResult: Bool,
                   callback: @escaping Result<ShiftUser, NSError>.Callback)
  func updateUserData(_ developerKey: String,
                      projectKey: String,
                      userToken: String,
                      userData: DataPointList,
                      callback: @escaping Result<ShiftUser, NSError>.Callback)
  func startPhoneVerification(_ developerKey: String,
                              projectKey: String,
                              phone: PhoneNumber,
                              callback: @escaping Result<Verification, NSError>.Callback)
  func startEmailVerification(_ developerKey: String,
                              projectKey: String,
                              email: Email,
                              callback: @escaping Result<Verification, NSError>.Callback)
  func startBirthDateVerification(_ developerKey: String,
                                  projectKey: String,
                                  birthDate: BirthDate,
                                  callback: @escaping Result<Verification, NSError>.Callback)
  func startDocumentVerification(_ developerKey: String,
                                 projectKey: String,
                                 userToken: String,
                                 documentImages: [UIImage],
                                 selfie: UIImage?,
                                 livenessData: [String: AnyObject]?,
                                 associatedTo workflowObject: WorkflowObject?,
                                 callback: @escaping Result<Verification, NSError>.Callback)
  func documentVerificationStatus(_ developerKey: String,
                                  projectKey: String,
                                  verificationId: String,
                                  callback: @escaping Result<Verification, NSError>.Callback)
  func completeVerification(_ developerKey: String,
                            projectKey: String,
                            verificationId: String,
                            secret: String?,
                            callback: @escaping Result<Verification, NSError>.Callback)
  func verificationStatus(_ developerKey: String,
                          projectKey: String,
                          verificationId: String,
                          callback: @escaping Result<Verification, NSError>.Callback)
  func restartVerification(_ developerKey: String,
                           projectKey: String,
                           verificationId: String,
                           callback: @escaping Result<Verification, NSError>.Callback)
}

class UserStorage: UserStorageProtocol {
  private let transport: JSONTransport

  init(transport: JSONTransport) {
    self.transport = transport
  }

  func createUser(_ developerKey: String,
                  projectKey: String,
                  userData: DataPointList,
                  callback: @escaping Result<ShiftUser, NSError>.Callback) {
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(), url: JSONRouter.createUser)
    let auth = JSONTransportAuthorization.accessToken(token: developerKey, projectToken: projectKey)
    let data: [String: AnyObject] = ["data_points": userData.jsonSerialize() as AnyObject]
    self.transport.post(url, authorization: auth, parameters: data, filterInvalidTokenResult: true) { result in
      callback(result.flatMap { json -> Result<ShiftUser, NSError> in
        guard let user = json.user else {
          return .failure(ServiceError(code: .jsonError))
        }
        return .success(user)
      })
    }
  }

  func loginWith(_ developerKey: String,
                 projectKey: String,
                 verifications: [Verification],
                 callback: @escaping Result<ShiftUser, NSError>.Callback) {
    guard let firstVerification = verifications.first, let secondVerification = verifications.last else {
      callback(.failure(BackendError(code: .incorrectParameters, reason: nil)))
      return
    }
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(), url: JSONRouter.login)
    let auth = JSONTransportAuthorization.accessToken(token: developerKey, projectToken: projectKey)
    let verificationsArray = [
      firstVerification.jsonSerialize(),
      secondVerification.jsonSerialize()
    ]
    let verificationsDictionary = [
      "data": verificationsArray
    ]
    let data: [String: AnyObject] = ["verifications": verificationsDictionary as AnyObject]
    self.transport.post(url, authorization: auth, parameters: data, filterInvalidTokenResult: true) { result in
      callback(result.flatMap { json -> Result<ShiftUser, NSError> in
        guard let user = json.user else {
          return .failure(ServiceError(code: .jsonError))
        }
        return .success(user)
      })
    }
  }

  func getUserData(_ developerKey: String,
                   projectKey: String,
                   userToken: String,
                   availableHousingTypes: [HousingType],
                   availableIncomeTypes: [IncomeType],
                   availableSalaryFrequencies: [SalaryFrequency],
                   filterInvalidTokenResult: Bool,
                   callback: @escaping Result<ShiftUser, NSError>.Callback) {
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(), url: JSONRouter.userInfo)
    let auth = JSONTransportAuthorization.accessAndUserToken(token: developerKey,
                                                             projectToken: projectKey,
                                                             userToken: userToken)
    self.transport.get(url,
                       authorization: auth,
                       parameters: nil,
                       headers: nil,
                       acceptRedirectTo: nil,
                       filterInvalidTokenResult: filterInvalidTokenResult) { result in
      callback(result.flatMap { json -> Result<ShiftUser, NSError> in
        guard let user = json.user else {
          return .failure(ServiceError(code: .jsonError))
        }
        if let housingList = user.userData.getDataPointsOf(type: .housing) as? [Housing] {
          for housing in housingList {
            let originalHousing = availableHousingTypes.filter {
              $0.housingTypeId == housing.housingType.value!.housingTypeId // swiftlint:disable:this force_unwrapping
            }
            if let first = originalHousing.first {
              housing.housingType.next(first)
            }
          }
        }
        if let incomeSourceList = user.userData.getDataPointsOf(type: .incomeSource) as? [IncomeSource] {
          for incomeSource in incomeSourceList {
            let originalIncomeType = availableIncomeTypes.filter {
              $0.incomeTypeId == incomeSource.incomeType.value!.incomeTypeId // swiftlint:disable:this force_unwrapping
            }
            if let first = originalIncomeType.first {
              incomeSource.incomeType.next(first)
            }
            let originalSalaryFrequency = availableSalaryFrequencies.filter {
              // swiftlint:disable:next force_unwrapping
              $0.salaryFrequencyId == incomeSource.salaryFrequency.value!.salaryFrequencyId
            }
            if let first = originalSalaryFrequency.first {
              incomeSource.salaryFrequency.next(first)
            }
          }
        }
        return .success(user)
      })
    }
  }

  func updateUserData(_ developerKey: String,
                      projectKey: String,
                      userToken: String,
                      userData: DataPointList,
                      callback: @escaping Result<ShiftUser, NSError>.Callback) {
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(), url: JSONRouter.updateUserInfo)
    let auth = JSONTransportAuthorization.accessAndUserToken(token: developerKey,
                                                             projectToken: projectKey,
                                                             userToken: userToken)
    let dataPointList = DataPointList()
    for dataPointBag in userData.dataPoints.values {
      for dataPoint in dataPointBag {
        dataPointList.add(dataPoint: dataPoint)
      }
    }
    if let ssnDataPoint = dataPointList.getDataPointsOf(type: .ssn)?.first as? SSN {
      if let notSpecified = ssnDataPoint.notSpecified {
        if !notSpecified {
          if ssnDataPoint.ssn.value == SSNTextValidator.unknownValidSSN {
            dataPointList.removeDataPointsOf(type: .ssn)
          }
        }
      }
      else {
        if ssnDataPoint.ssn.value == SSNTextValidator.unknownValidSSN {
          dataPointList.removeDataPointsOf(type: .ssn)
        }
      }
    }
    let data: [String: AnyObject] = ["data_points": dataPointList.jsonSerialize() as AnyObject]
    self.transport.put(url, authorization: auth, parameters: data, filterInvalidTokenResult: true) { result in
      callback(result.flatMap { json -> Result<ShiftUser, NSError> in
        guard let user = json.user else {
          return .failure(ServiceError(code: .jsonError))
        }
        return .success(user)
      })
    }
  }

  func startPhoneVerification(_ developerKey: String,
                              projectKey: String,
                              phone: PhoneNumber,
                              callback: @escaping Result<Verification, NSError>.Callback) {
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(), url: JSONRouter.verificationStart)
    let auth = JSONTransportAuthorization.accessToken(token: developerKey, projectToken: projectKey)
    let data = [
      "datapoint_type": "phone" as AnyObject,
      "show_verification_secret": true as AnyObject,
      "datapoint": [
        "country_code": phone.countryCode.value as AnyObject,
        "phone_number": phone.phoneNumber.value as AnyObject
      ] as [String: AnyObject]
    ] as [String: AnyObject]
    self.transport.post(url, authorization: auth, parameters: data, filterInvalidTokenResult: true) { result in
      callback(result.flatMap { json -> Result<Verification, NSError> in
        guard let verification = json.verification else {
          return .failure(ServiceError(code: .jsonError))
        }
        AutomationStorage.verificationSecret = verification.secret
        return .success(verification)
      })
    }
  }

  func startEmailVerification(_ developerKey: String,
                              projectKey: String,
                              email: Email,
                              callback: @escaping Result<Verification, NSError>.Callback) {
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(), url: JSONRouter.verificationStart)
    let auth = JSONTransportAuthorization.accessToken(token: developerKey, projectToken: projectKey)
    let data = [
      "datapoint_type": "email" as AnyObject,
      "show_verification_secret": true as AnyObject,
      "datapoint": [
        "email": email.email.value as AnyObject
      ] as [String: AnyObject]
    ] as [String: AnyObject]
    self.transport.post(url, authorization: auth, parameters: data, filterInvalidTokenResult: true) { result in
      callback(result.flatMap { json -> Result<Verification, NSError> in
        guard let verification = json.verification else {
          return .failure(ServiceError(code: .jsonError))
        }
        AutomationStorage.verificationSecret = verification.secret
        return .success(verification)
      })
    }
  }

  func startBirthDateVerification(_ developerKey: String,
                                  projectKey: String,
                                  birthDate: BirthDate,
                                  callback: @escaping Result<Verification, NSError>.Callback) {
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(), url: JSONRouter.verificationStart)
    let auth = JSONTransportAuthorization.accessToken(token: developerKey, projectToken: projectKey)
    let data = [
      "datapoint_type": "birthDate" as AnyObject,
      "show_verification_secret": true as AnyObject,
      "datapoint": [
        "date": birthDate.date.value?.formatForJSONAPI() as AnyObject? ?? NSNull()
      ] as [String: AnyObject]
    ] as [String: AnyObject]
    self.transport.post(url, authorization: auth, parameters: data, filterInvalidTokenResult: true) { result in
      callback(result.flatMap { json -> Result<Verification, NSError> in
        guard let verification = json.verification else {
          return .failure(ServiceError(code: .jsonError))
        }
        AutomationStorage.verificationSecret = verification.secret
        return .success(verification)
      })
    }
  }

  func startDocumentVerification(_ developerKey: String,
                                 projectKey: String,
                                 userToken: String,
                                 documentImages: [UIImage],
                                 selfie: UIImage?,
                                 livenessData: [String: AnyObject]?,
                                 associatedTo workflowObject: WorkflowObject?,
                                 callback: @escaping Result<Verification, NSError>.Callback) {
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(), url: JSONRouter.documentOCR)
    let auth = JSONTransportAuthorization.accessAndUserToken(token: developerKey,
                                                             projectToken: projectKey,
                                                             userToken: userToken)
    let imagesData = documentImages.map { image -> [String: String] in
      return ["image_array": image.toBase64()]
    }
    var selfieData: [String: String]? = nil
    if let selfie = selfie {
      selfieData = ["image_array": selfie.toBase64()]
    }
    var data = [
      "datapoint_type": "AU10TIX" as AnyObject,
      "datapoint": [
        "document_images": imagesData as AnyObject,
        "selfie": selfieData as AnyObject,
        "liveness_data": livenessData as AnyObject
      ] as [String: AnyObject]
    ] as [String: AnyObject]
    if let workflowId = workflowObject?.workflowObjectId {
      data["workflow_object_id"] = workflowId as AnyObject
    }
    self.transport.post(url, authorization: auth, parameters: data, filterInvalidTokenResult: true) { result in
      callback(result.flatMap { json -> Result<Verification, NSError> in
        guard let verification = json.verification else {
          return .failure(ServiceError(code: .jsonError))
        }
        AutomationStorage.verificationSecret = verification.secret
        return .success(verification)
      })
    }
  }

  func documentVerificationStatus(_ developerKey: String,
                                  projectKey: String,
                                  verificationId: String,
                                  callback: @escaping Result<Verification, NSError>.Callback) {
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(),
                         url: JSONRouter.documentOCRStatus,
                         urlParameters: [":verificationId": verificationId])
    let auth = JSONTransportAuthorization.accessToken(token: developerKey, projectToken: projectKey)
    self.transport.get(url,
                       authorization: auth,
                       parameters: nil,
                       headers: nil,
                       acceptRedirectTo: nil,
                       filterInvalidTokenResult: true) { result in
      callback(result.flatMap { json -> Result<Verification, NSError> in
        guard let verification = json.verification else {
          return .failure(ServiceError(code: .jsonError))
        }
        return .success(verification)
      })
    }
  }

  func completeVerification(_ developerKey: String,
                            projectKey: String,
                            verificationId: String,
                            secret: String?,
                            callback: @escaping Result<Verification, NSError>.Callback) {
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(),
                         url: JSONRouter.verificationFinish,
                         urlParameters: [":verificationId": verificationId])
    let auth = JSONTransportAuthorization.accessToken(token: developerKey, projectToken: projectKey)
    let data = [
      "secret": secret as AnyObject
    ]
    self.transport.post(url, authorization: auth, parameters: data, filterInvalidTokenResult: true) { result in
      callback(result.flatMap { json -> Result<Verification, NSError> in
        guard let verification = json.verification else {
          return .failure(ServiceError(code: .jsonError))
        }
        return .success(verification)
      })
    }
  }

  func verificationStatus(_ developerKey: String,
                          projectKey: String,
                          verificationId: String,
                          callback: @escaping Result<Verification, NSError>.Callback) {
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(),
                         url: JSONRouter.verificationStatus,
                         urlParameters: [":verificationId": verificationId])
    let auth = JSONTransportAuthorization.accessToken(token: developerKey, projectToken: projectKey)
    self.transport.get(url,
                       authorization: auth,
                       parameters: nil,
                       headers: nil,
                       acceptRedirectTo: nil,
                       filterInvalidTokenResult: true) { result in
      callback(result.flatMap { json -> Result<Verification, NSError> in
        guard let verification = json.verification else {
          return .failure(ServiceError(code: .jsonError))
        }
        return .success(verification)
      })
    }
  }

  func restartVerification(_ developerKey: String,
                           projectKey: String,
                           verificationId: String,
                           callback: @escaping Result<Verification, NSError>.Callback) {
    let url = URLWrapper(baseUrl: self.transport.environment.baseUrl(),
                         url: JSONRouter.verificationRestart,
                         urlParameters: [":verificationId": verificationId])
    let auth = JSONTransportAuthorization.accessToken(token: developerKey, projectToken: projectKey)
    self.transport.post(url, authorization: auth, parameters: nil, filterInvalidTokenResult: true) { result in
      callback(result.flatMap { json -> Result<Verification, NSError> in
        guard let verification = json.verification else {
          return .failure(ServiceError(code: .jsonError))
        }
        return .success(verification)
      })
    }
  }
}