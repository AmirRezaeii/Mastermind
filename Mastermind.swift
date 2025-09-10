import FoundationNetworking
import Foundation

struct CreateGameResponse: Codable {
    let game_id: String
}

struct GuessRequest: Codable {
    let game_id: String
    let guess: String
}

struct GuessResponse: Codable {
    let black: Int
    let white: Int
}

struct ErrorResponse: Codable {
    let error: String
}

func createGame(completion: @escaping (String?) -> Void) {
    guard let url = URL(string: "https://mastermind.darkube.app/game") else {
        completion(nil)
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    URLSession.shared.dataTask(with: request) { data, _, _ in
        guard let data = data else {
            completion(nil)
            return
        }

        if let game = try? JSONDecoder().decode(CreateGameResponse.self, from: data) {
            completion(game.game_id)
        } else {
            _ = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            completion(nil)
        }
    }.resume()
}

func makeGuess(gameID: String, guess: String, completion: @escaping (GuessResponse?) -> Void) {
    guard let url = URL(string: "https://mastermind.darkube.app/guess") else {
        completion(nil)
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = GuessRequest(game_id: gameID, guess: guess)
    guard let jsonData = try? JSONEncoder().encode(body) else {
        completion(nil)
        return
    }

    request.httpBody = jsonData

    URLSession.shared.dataTask(with: request) { data, _, _ in
        guard let data = data else {
            completion(nil)
            return
        }

        if let guessResp = try? JSONDecoder().decode(GuessResponse.self, from: data) {
            print("Result → Black: \(guessResp.black), White: \(guessResp.white)")
            completion(guessResp)
        } else {
            _ = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            completion(nil)
        }
    }.resume()
}

func deleteGame(gameID: String, completion: @escaping () -> Void) {
    guard let url = URL(string: "https://mastermind.darkube.app/game/\(gameID)") else {
        completion()
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"

    URLSession.shared.dataTask(with: request) { _, response, _ in
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 {
            print("Game \(gameID) deleted successfully")
        }
        completion()
    }.resume()
}

var gameID: String?

print("Welcome to Mastermind")
print("Commands:")
print("  new game   → start a new game")
print("  exit       → quit the program")
print("  delete game → delete the current game")
print("Enter 4-digit guesses when a game is active (digits 1–6)")

func startNewGame() {
    let semaphore = DispatchSemaphore(value: 0)
    createGame { id in
        if let id = id {
            gameID = id
            print("New game created. Game ID: \(id)")
            print("Start guessing!")
        } else {
            print("Failed to create a new game.")
        }
        semaphore.signal()
    }
    semaphore.wait()
}

while true {
    print("\n> ", terminator: "")
    guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else { continue }

    switch input.lowercased() {
    case "exit":
        if let id = gameID {
            deleteGame(gameID: id) { exit(0) }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        } else {
            exit(0)
        }

    case "delete game":
        if let id = gameID {
            deleteGame(gameID: id) { gameID = nil }
        } else {
            print("No active game to delete.")
        }

    case "new game":
        startNewGame()

    default:
        guard let id = gameID else {
            print("No active game. Type 'new game' to start a new game.")
            continue
        }

        if input.count == 4 && input.allSatisfy({ "123456".contains($0) }) {
            let guessSemaphore = DispatchSemaphore(value: 0)
            makeGuess(gameID: id, guess: input) { response in
                if let resp = response, resp.black == 4 {
                    print("You win!")
                    deleteGame(gameID: id) {
                        gameID = nil
                        print("Type 'new game' to start another game.")
                    }
                }
                guessSemaphore.signal()
            }
            guessSemaphore.wait()
        } else {
            print("Invalid input. Use 4 digits between 1–6, or type 'delete game' or 'exit'.")
        }
    }
}
