from PIL import Image, ImageDraw

def create_play_button(size=64):
    # Create a transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw a play triangle
    points = [(size//4, size//4), (size//4, size*3//4), (size*3//4, size//2)]
    draw.polygon(points, fill=(255, 255, 255, 255))
    
    img.save('assets/ui/basic/play.png')

def create_arrow(size=64):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw an arrow
    points = [(size//4, size//2), (size//2, size//4), (size//2, size*3//8),
             (size*3//4, size*3//8), (size*3//4, size*5//8), (size//2, size*5//8),
             (size//2, size*3//4)]
    draw.polygon(points, fill=(255, 255, 255, 255))
    
    img.save('assets/ui/basic/arrow.png')

def create_colored_square(color, name, size=64):
    img = Image.new('RGBA', (size, size), color)
    img.save(f'assets/ui/basic/{name}.png')

# Generate all UI elements
create_play_button()
create_arrow()
create_colored_square((255, 0, 0, 255), 'red')
create_colored_square((0, 255, 0, 255), 'green')
create_colored_square((255, 255, 0, 255), 'yellow') 