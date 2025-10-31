// Скрипт для генерации manifest.json со списком файлов из папки Result
// Запуск: node generate-manifest.js

const fs = require('fs');
const path = require('path');

const resultDir = path.join(__dirname, 'Result');
const manifestPath = path.join(resultDir, 'manifest.json');

try {
    // Проверяем существование папки Result
    if (!fs.existsSync(resultDir)) {
        console.error('Папка Result не найдена!');
        process.exit(1);
    }

    // Получаем список всех HTML файлов
    const files = fs.readdirSync(resultDir)
        .filter(file => file.endsWith('.html'))
        .map(file => {
            const filePath = path.join(resultDir, file);
            const stats = fs.statSync(filePath);
            
            // Извлекаем дату из имени файла
            const dateMatch = file.match(/(\d{4})-?(\d{2})-?(\d{2})/);
            let date = null;
            if (dateMatch) {
                date = new Date(dateMatch[1], parseInt(dateMatch[2]) - 1, dateMatch[3]);
            }
            
            return {
                name: file,
                date: stats.mtime.toISOString(),
                commitDate: date ? date.toISOString() : stats.mtime.toISOString()
            };
        })
        .sort((a, b) => {
            // Сортируем по дате (новые сверху)
            const dateA = new Date(a.commitDate || a.date);
            const dateB = new Date(b.commitDate || b.date);
            return dateB - dateA;
        });

    // Создаем manifest.json
    const manifest = {
        files: files,
        generated: new Date().toISOString()
    };

    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
    
    console.log(`✅ Успешно создан manifest.json с ${files.length} файлом(ами):`);
    files.forEach(file => {
        console.log(`   - ${file.name}`);
    });
    
} catch (error) {
    console.error('Ошибка при создании manifest.json:', error);
    process.exit(1);
}

