/**
 * Template de cenário Playwright. O pack não instala a dependência.
 * Copie para o projeto de teste só dentro do envelope aprovado.
 * Substitua os nomes fictícios. Não grave segredo nem dado de cliente.
 */
import { test, expect } from '@playwright/test';

const criterio = 'C01-fixture';

test('criterio de tela ficticio', async ({ page }) => {
  await page.goto('/fixture');
  await page.getByRole('button', { name: 'Confirmar fixture' }).click();
  await page.screenshot({ path: `evidencias/${criterio}-passo.png` });
  await expect(page.getByText('fixture ok')).toBeVisible();
  await page.screenshot({ path: `evidencias/${criterio}-final.png` });
});
