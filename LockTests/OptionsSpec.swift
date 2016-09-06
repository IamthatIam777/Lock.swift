// OptionsSpec.swift
//
// Copyright (c) 2016 Auth0 (http://auth0.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Quick
import Nimble

@testable import Lock

class OptionsSpec: QuickSpec {

    override func spec() {

        var options: LockOptions!

        beforeEach {
            options = LockOptions()
        }

        describe("defaults") {

            it("should not be closable") {
                expect(options.closable) == false
            }

            it("should have Auth0 tos as String") {
                expect(options.termsOfService) == "https://auth0.com/terms"
            }

            it("should have Auth0 tos as NSURL") {
                expect(options.termsOfServiceURL.absoluteString) == "https://auth0.com/terms"
            }

            it("should have Auth0 privacy policy as String") {
                expect(options.privacyPolicy) == "https://auth0.com/privacy"
            }

            it("should have Auth0 privacy policy as NSURL") {
                expect(options.privacyPolicyURL.absoluteString) == "https://auth0.com/privacy"
            }

            it("should have openid as scope") {
                expect(options.scope) == "openid"
            }

            it("should have empty default parameters") {
                expect(options.parameters).to(beEmpty())
            }

        }

        describe("builder") {

            it("should set closable") {
                options.closable = true
                expect(options.closable) == true
            }

            it("should set tos") {
                options.termsOfService = "https://mysite.com"
                expect(options.termsOfServiceURL.absoluteString) == "https://mysite.com"
            }

            it("should ignore invalid tos") {
                options.termsOfService = "not a url"
                expect(options.termsOfServiceURL.absoluteString) == "https://auth0.com/terms"
            }

            it("should set privacy policy") {
                options.privacyPolicy = "https://mysite.com"
                expect(options.privacyPolicyURL.absoluteString) == "https://mysite.com"
            }

            it("should ignore invalid privacy policy") {
                options.privacyPolicy = "not a url"
                expect(options.privacyPolicyURL.absoluteString) == "https://auth0.com/privacy"
            }

        }
    }
}