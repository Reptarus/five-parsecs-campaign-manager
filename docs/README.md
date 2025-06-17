# 🚀 Five Parsecs from Home Campaign Manager - Alpha Release Ready!

## 🎯 **Current Status: ALPHA COMPLETE**

**Achievement**: ✅ **Complete Five Parsecs Campaign Manager** - **Alpha systems integrated!**  
**Status**: Fully functional alpha with complete campaign turn flow  
**Release**: Ready for alpha deployment with all core systems working

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Features](#features)
3. [Technology Stack](#technology-stack)
4. [Getting Started](#getting-started)
   - [Prerequisites](#prerequisites)
   - [Installation](#installation)
5. [Usage](#usage)
6. [Project Structure](#project-structure)
7. [Contributing](#contributing)
8. [License](#license)
9. [Acknowledgments](#acknowledgments)

## Project Overview

The Five Parsecs from Home Campaign Manager is a digital tool designed to streamline and enhance the gameplay experience of the tabletop miniatures game "Five Parsecs from Home". This application automates various aspects of campaign management, allowing players to focus on the narrative and tactical elements of the game.

Our goal is to provide a user-friendly interface that closely adheres to the rules presented in the core rulebook while offering additional features to enrich the gaming experience.

## Features

- **Character Creation and Management**: Create and customize characters with various attributes, skills, and backgrounds.
- **Crew Management**: Organize and manage your crew, including recruitment and dismissal.
- **Mission Generation**: Automatically generate varied and exciting missions based on the game's rules.
- **Patron Job System**: Manage relationships with patrons and take on special jobs.
- **Pre-Battle Preparation**: Set up battles, including deployment and terrain generation.
- **Post-Battle Sequence**: Handle the aftermath of battles, including loot, experience, and injuries.
- **Equipment and Inventory Management**: Manage your crew's gear and ship's inventory.
- **Experience and Skill Progression**: Track character growth and skill improvements.
- **Galactic War and Invasion Mechanics**: Simulate the larger conflicts in the game universe.
- **Starship Management**: Manage your crew's spaceship, including upgrades and travel.
- **Economy System**: Handle credits, trading, and economic events.

## Technology Stack

- **Game Engine**: Godot 4.3
- **Programming Language**: GDScript
- **Version Control**: Git

## Getting Started

### Prerequisites

- Godot Engine 4.3 or later
- Git (for version control)

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/five-parsecs-campaign-manager.git
   ```

2. Open the project in Godot Engine:
   - Launch Godot Engine
   - Select "Import"
   - Navigate to the cloned repository and select the `project.godot` file

3. Run the project:
   - Click the "Play" button in the Godot editor or press F5

## Usage

1. **Start a New Campaign**:
   - From the main menu, select "New Campaign"
   - Follow the prompts to create your initial crew and ship

2. **Manage Your Crew**:
   - Use the Crew Management screen to add, remove, or edit crew members
   - Equip your crew with weapons and gear

3. **Embark on Missions**:
   - From the Campaign Dashboard, select "Find Mission"
   - Choose from available missions or generate a new one

4. **Resolve Battles**:
   - Use the pre-battle setup to position your crew
   - Resolve the battle manually using your tabletop setup
   - Input the results into the post-battle screen

5. **Progress Your Campaign**:
   - Manage your ship, trade equipment, and interact with patrons between missions
   - Watch your crew grow and the galaxy change around you

## Project Structure

- `/scripts`: Contains all GDScript files
  - `/core`: Core game logic (GameState, CampaignManager, etc.)
  - `/characters`: Character and crew-related scripts
  - `/missions`: Mission generation and management
  - `/combat`: Combat-related scripts
  - `/economy`: Economic systems and trading
  - `/ship`: Spaceship management
- `/scenes`: Godot scene files
- `/assets`: Game assets (images, sounds, etc.)
- `/data`: Data files (e.g., equipment lists, name generators)
- `/tests`: Testing infrastructure (gdUnit4)
- `/docs`: Project documentation
  - `/testing`: Current testing documentation and status
  - `/archive`: Historical and deprecated documentation

## Contributing

We welcome contributions to the Five Parsecs from Home Campaign Manager! If you'd like to contribute, please follow these steps:

1. Fork the repository
2. Create a new branch (`git checkout -b feature/AmazingFeature`)
3. Make your changes
4. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
5. Push to the branch (`git push origin feature/AmazingFeature`)
6. Open a Pull Request

Please make sure to update tests as appropriate and adhere to the project's coding standards.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## Acknowledgments

- Thanks to Ivan Barontini and Modiphius Entertainment for creating the amazing "Five Parsecs from Home" game.
- All contributors who have helped to build and improve this project.

---

For more information or support, please open an issue on the GitHub repository or contact the project maintainers.
