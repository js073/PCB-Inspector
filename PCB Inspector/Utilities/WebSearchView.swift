//
//  WebSearchView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 18/12/2023.
//
//  Provides a view for a web search with a given URL

import SwiftUI
import WebKit

/// Main websearch view, with the page URL passed as a parameter
struct WebSearchView: View {
    @Binding var webPageURL: String
    @State private var isLoading = true
    var isShowingCloseButton: Bool = false
    var closingAction: (() -> ())?
    @State var goBack: (() -> WKNavigation?)?
    @State var goForward: (() -> WKNavigation?)?
    @State var canGoBack: Bool = false
    @State var canGoForward: Bool = false
    @State var reload: (() -> WKNavigation?)?
    
    var body: some View {
        ZStack {
            Text(webPageURL) // Display the page URL at the top
                .padding([.top, .bottom, .leading, .trailing], 5)
                .bold()
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.background)
                }
            HStack {
                if isShowingCloseButton {
                    Button {
                        closingAction?()
                    } label: {
                        Text("x")
                    }
                    .buttonStyle(SmallAccentButtonStyle())
                    Spacer()
                }
            }

        }
        .padding([.top, .bottom], 5)
        .padding([.leading, .trailing], 10)
        if let url = URL(string: webPageURL) {
            WebPageView(loadedFunc: { stopLoading() }, contentURL: url, isLoading: $isLoading, goBack: $goBack, goForward: $goForward, canGoBack: $canGoBack, canGoForward: $canGoForward, reload: $reload)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .overlay {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.accent)
                            .scaleEffect(2)
                            .padding(.all, 40)
                            .background {
                                RoundedRectangle(cornerRadius: 25)
                                    .foregroundStyle(.backgroundColourVariant)
                            }
                    }
                }
                .overlay(alignment: .bottom) { // Navigation buttons on the bottom
                    HStack {
                        Button {
                            let _ = goBack?()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                        }
                        .buttonStyle(SmallAccentButtonStyle())
                        .disabled(!canGoBack)
                        .opacity(!canGoBack ? 0.3 : 1)
                        
                        Spacer()
                            .frame(maxWidth: 20)
                        
                        Button {
                            let _ = reload?()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                        }
                        .buttonStyle(SmallMonoButtonStyle())
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.3 : 1)
                        
                        Spacer()
                            .frame(maxWidth: 20)
                        
                        Button {
                            let _ = goForward?()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                        }
                        .buttonStyle(SmallAccentButtonStyle())
                        .disabled(!canGoForward)
                        .opacity(!canGoForward ? 0.3 : 1)
                    }
                    .padding(.bottom, 10)
                }
        }
        
    }
    
    private func stopLoading() {
        self.isLoading = false
        print("stopping, \(self.isLoading)")
    }
}

/// Encode a search question into a Google search format
fileprivate func encodeRequestURL(_ searchTerms: String) -> URL? {
    let formattedTerms = searchTerms.replacingOccurrences(of: " ", with: "+")
    let url = "https://www.google.com/search?q=\(formattedTerms)"
    return URL(string: url)
}

// Adapted from https://www.swiftyplace.com/blog/loading-a-web-view-in-swiftui-with-wkwebview
struct WebPageView: UIViewRepresentable { // Creates the web view and loading icons
    let loadedFunc: () -> ()
    let contentURL: URL
    @Binding var isLoading: Bool
    @Binding var goBack: (() -> WKNavigation?)?
    @Binding var goForward: (() -> WKNavigation?)?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var reload: (() -> WKNavigation?)?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: contentURL))
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebPageView
        
        init(parent: WebPageView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print(navigation.description)
            parent.isLoading = true
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.setValues(webView)
        }
    }
    
    /// Function to set values for webview
    func setValues(_ webView: WKWebView) {
        goBack = webView.goBack
        goForward = webView.goForward
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        reload = webView.reload
    }
}


#Preview {
    WebSearchView(webPageURL: .constant("https://datasheet.octopart.com/PIC18F44J10-I/PT-Microchip-datasheet-8383908.pdf"))
}
